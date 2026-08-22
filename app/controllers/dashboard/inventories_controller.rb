class Dashboard::InventoriesController < Dashboard::BaseController
  def index
    @variants = ProductVariant.includes(:product, :product_option_values)
                              .joins(:product)
                              .search_by_product_name(params[:q])

    @pagy, @variants = pagy(@variants.order("products.name ASC, product_variants.title ASC"))
  end

  def update_all
    updates = params[:variants] || {}
    variant_ids = updates.keys

    success_count = ProductVariant.transaction do
      variants = ProductVariant.lock
                               .where(id: variant_ids)
                               .order(:id)
                               .index_by { |variant| variant.id.to_s }

      missing_ids = variant_ids - variants.keys
      raise ActiveRecord::RecordNotFound, "Couldn't find ProductVariant with ID: #{missing_ids.join(', ')}" if missing_ids.any?

      success_count = 0
      updates.each do |variant_id, variant_params|
        variant = variants.fetch(variant_id)
        delta = variant_params[:stock].to_i - variant.stock
        next if delta.zero?

        InventoryMovement.create!(
          product_variant: variant,
          quantity: delta,
          reason: :adjustment,
          user: Current.user,
          note: "Manual adjustment via dashboard"
        )
        success_count += 1
      end
      success_count
    end

    redirect_to dashboard_inventory_path(q: params[:q], page: params[:page]),
                notice: "Updated inventory for #{success_count} variants."
  end
end
