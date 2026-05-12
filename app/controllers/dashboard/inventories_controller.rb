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
      if variant.update(stock: variant_params[:stock])
        success_count += 1
      end
    end

    redirect_to dashboard_inventory_path(q: params[:q], page: params[:page]), 
                notice: "Successfully updated stock for #{success_count} variants."
  end
end
