class Dashboard::InventoriesController < Dashboard::BaseController
  def index
    # We want to manage variants directly
    @variants = ProductVariant.includes(:product, :product_option_values)
                              .joins(:product)
                              .search_by_product_name(params[:q])

    @pagy, @variants = pagy(@variants.order("products.name ASC, product_variants.title ASC"))
  end

  def update_all
    updates = params[:variants] || {}

    success_count = 0
    updates.each do |variant_id, variant_params|
      variant = ProductVariant.find(variant_id)
      delta = variant_params[:stock].to_i - variant.stock.to_i
      next if delta == 0

      InventoryMovement.create!(
        product_variant: variant,
        quantity: delta,
        reason: :adjustment,
        user: Current.user,
        note: "Manual adjustment via dashboard"
      )
      success_count += 1
    end

    redirect_to dashboard_inventory_path(q: params[:q], page: params[:page]),
                notice: "Updated inventory for #{success_count} variants."
  end
end
