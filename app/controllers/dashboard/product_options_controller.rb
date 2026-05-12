class Dashboard::ProductOptionsController < Dashboard::BaseController
  before_action :set_product, only: %i[create]
  before_action :set_option, only: %i[destroy]

  def create
    @option = @product.product_options.build(option_params)
    @option.position = @product.product_options.count + 1

    if @option.save
      redirect_to edit_dashboard_product_path(@product),
                  notice: "Option '#{@option.name}' added"
    else
      redirect_to edit_dashboard_product_path(@product),
                  alert: @option.errors.full_messages.to_sentence
    end
  end

  def destroy
    product = @option.product
    @option.destroy

    redirect_to edit_dashboard_product_path(product),
                notice: "Option removed"
  end

  private

  def set_product
    @product = Product.find(params[:product_id])
  end

  def set_option
    @option = ProductOption.find(params[:id])
  end

  def option_params
    params.require(:product_option).permit(
      :name,
      product_option_values_attributes: %i[id value position _destroy]
    )
  end
end
