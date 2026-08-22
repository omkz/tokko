require "rails_helper"
require "timeout"

RSpec.describe "Order checkout concurrency", type: :model do
  self.use_transactional_tests = false

  before do
    @cart_ids = []
    @coupon_ids = []
    @product_ids = []
  end

  after do
    product_variant_ids = ProductVariant.where(product_id: @product_ids).ids
    order_ids = Order.where(cart_id: @cart_ids).ids
    order_item_ids = OrderItem.where(order_id: order_ids).ids

    InventoryMovement.where(product_variant_id: product_variant_ids).delete_all
    OrderItem.where(id: order_item_ids).delete_all
    Order.where(id: order_ids).delete_all
    CartItem.where(cart_id: @cart_ids).delete_all
    Cart.where(id: @cart_ids).delete_all
    Coupon.where(id: @coupon_ids).delete_all
    VariantOptionValue.where(product_variant_id: product_variant_ids).delete_all
    ProductVariant.where(id: product_variant_ids).delete_all
    FriendlyId::Slug.where(sluggable_type: "Product", sluggable_id: @product_ids).delete_all
    Product.where(id: @product_ids).delete_all
  end

  it "allows only one checkout to reserve the final stock unit" do
    _product, variant = create_catalog(stock: 1)
    cart_ids = [ create_cart(variant), create_cart(variant) ]

    results, connection_ids = run_concurrently(
      -> { checkout(cart_ids.first) },
      -> { checkout(cart_ids.second) }
    )

    persisted, rejected = results.partition { |order, _errors| order.persisted? }

    expect(connection_ids.uniq.size).to eq(2)
    expect(persisted.size).to eq(1)
    expect(rejected.size).to eq(1)
    expect(rejected.first.last).not_to be_empty
    expect(variant.reload.stock).to eq(0)
    expect(variant.stock).to be >= 0
    expect(InventoryMovement.reservation.where(product_variant: variant).count).to eq(1)
  end

  it "allows only one checkout to reserve a usage-limited coupon" do
    _product, variant = create_catalog(stock: 2)
    cart_ids = [ create_cart(variant), create_cart(variant) ]
    coupon = create(:coupon, usage_limit: 1)
    @coupon_ids << coupon.id

    results, connection_ids = run_concurrently(
      -> { checkout(cart_ids.first, coupon_code: coupon.code) },
      -> { checkout(cart_ids.second, coupon_code: coupon.code) }
    )

    persisted, rejected = results.partition { |order, _errors| order.persisted? }

    expect(connection_ids.uniq.size).to eq(2)
    expect(persisted.size).to eq(1)
    expect(rejected.size).to eq(1)
    expect(rejected.first.first.errors.full_messages).to include("Coupon is no longer available")
    expect(coupon.orders.pending).to contain_exactly(persisted.first.first)
    expect(InventoryMovement.reservation.where(product_variant: variant).count).to eq(1)
    expect(variant.reload.stock).to eq(1)
  end

  it "rejects checkout when product archival obtains the lock first" do
    product, variant = create_catalog(stock: 1)
    cart_id = create_cart(variant)
    product_locked = Queue.new
    archive_release = Queue.new
    checkout_connection = Queue.new
    outcomes = Queue.new
    workers = []

    workers << database_worker(outcomes) do
      Product.transaction do
        locked_product = Product.lock.find(product.id)
        locked_product.archive!
        product_locked << true
        archive_release.pop
      end
      [ :archive, true ]
    end

    wait_for(product_locked)

    workers << database_worker(outcomes) do |connection|
      checkout_connection << connection.raw_connection.backend_pid
      [ :checkout, checkout(cart_id) ]
    end

    wait_for_database_lock(wait_for(checkout_connection))
    archive_release << true
    join_workers(workers)
    results, connection_ids = collect_outcomes(outcomes, workers.size)
    checkout_result = results.assoc(:checkout).last

    expect(connection_ids.uniq.size).to eq(2)
    expect(product.reload).to be_archived
    expect(checkout_result.first).not_to be_persisted
    expect(checkout_result.last).to include(a_string_matching(/is no longer available/))
    expect(variant.reload.stock).to eq(1)
    expect(InventoryMovement.reservation.where(product_variant: variant)).to be_empty
  ensure
    archive_release << true if archive_release
    join_workers(workers) if workers&.any?(&:alive?)
  end

  it "allows checkout to reserve stock when it obtains the product lock first" do
    product, variant = create_catalog(stock: 1)
    cart_id = create_cart(variant)
    checkout_reserved = Queue.new
    checkout_release = Queue.new
    archive_started = Queue.new
    outcomes = Queue.new
    workers = []

    workers << database_worker(outcomes) do
      result = nil
      Order.transaction do
        result = checkout(cart_id)
        checkout_reserved << true
        checkout_release.pop
      end
      [ :checkout, result ]
    end

    wait_for(checkout_reserved)

    workers << database_worker(outcomes) do |connection|
      archive_started << connection.raw_connection.backend_pid
      Product.find(product.id).archive!
      [ :archive, true ]
    end

    wait_for_database_lock(wait_for(archive_started))
    checkout_release << true
    join_workers(workers)
    results, connection_ids = collect_outcomes(outcomes, workers.size)
    checkout_result = results.assoc(:checkout).last

    expect(connection_ids.uniq.size).to eq(2)
    expect(checkout_result.first).to be_persisted
    expect(checkout_result.last).to be_empty
    expect(product.reload).to be_archived
    expect(variant.reload.stock).to eq(0)
    expect(InventoryMovement.reservation.where(product_variant: variant).count).to eq(1)
  ensure
    checkout_release << true if checkout_release
    join_workers(workers) if workers&.any?(&:alive?)
  end

  private

  def create_catalog(stock:)
    product = create(:product, name: "Concurrency Product #{SecureRandom.hex(6)}")
    @product_ids << product.id
    variant = product.product_variants.sole
    variant.update!(price: 10_000, stock: stock, active: true)
    [ product, variant ]
  end

  def create_cart(variant)
    cart = create(:cart)
    @cart_ids << cart.id
    create(:cart_item, cart: cart, product_variant: variant, quantity: 1)
    cart.id
  end

  def checkout(cart_id, coupon_code: nil)
    Order.create_from_cart!(
      Cart.find(cart_id),
      {
        customer_name: "Concurrent Customer",
        customer_email: "concurrent@example.com",
        shipping_address: "Jakarta"
      },
      coupon_code: coupon_code
    )
  end

  def run_concurrently(*operations)
    ready = Queue.new
    start = Queue.new
    outcomes = Queue.new
    workers = operations.map do |operation|
      database_worker(outcomes) do
        ready << true
        start.pop
        operation.call
      end
    end

    operations.size.times { wait_for(ready) }
    operations.size.times { start << true }
    join_workers(workers)
    collect_outcomes(outcomes, workers.size)
  ensure
    operations&.size&.times { start << true } if start
    join_workers(workers) if workers&.any?(&:alive?)
  end

  def database_worker(outcomes, &work)
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        outcomes << {
          value: work.call(connection),
          connection_id: connection.raw_connection.backend_pid
        }
      end
    rescue StandardError => error
      Thread.current[:worker_error] = error
      outcomes << { error: error }
    end
  end

  def collect_outcomes(outcomes, count)
    entries = count.times.map { wait_for(outcomes) }
    error = entries.filter_map { |entry| entry[:error] }.first
    raise error if error

    [ entries.map { |entry| entry[:value] }, entries.map { |entry| entry[:connection_id] } ]
  end

  def wait_for(queue)
    Timeout.timeout(10) { queue.pop }
  end

  def wait_for_database_lock(connection_id)
    Prosopite.pause do
      Timeout.timeout(10) do
        loop do
          blockers = ActiveRecord::Base.connection.select_value(
            "SELECT cardinality(pg_blocking_pids(#{Integer(connection_id)}))"
          )
          break if blockers.positive?

          Thread.pass
        end
      end
    end
  end

  def join_workers(workers)
    Timeout.timeout(10) { workers.each(&:join) }
    error = workers.filter_map { |worker| worker[:worker_error] }.first
    raise error if error
  rescue Timeout::Error
    workers.each(&:kill)
    workers.each(&:join)
    raise
  end
end
