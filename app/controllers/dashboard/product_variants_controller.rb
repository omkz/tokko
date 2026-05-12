class Dashboard::ProductVariantsController < Dashboard::BaseController
  before_action :set_variant, only: %i[update destroy]

  # PATCH /product_variants/:id
  def update
    respond_to do |format|
      if @variant.update(variant_params)
        format.html { redirect_to edit_dashboard_product_path(@variant.product), notice: "Variant saved" }
        format.turbo_stream
      else
        format.html { redirect_to edit_dashboard_product_path(@variant.product), alert: @variant.errors.full_messages.to_sentence }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("variant_row_#{@variant.id}", partial: "dashboard/products/variant_row", locals: { variant: @variant }) }
      end
    end
  end

  # DELETE /product_variants/:id
  def destroy
    product = @variant.product
    @variant.destroy
    
    respond_to do |format|
      format.html { redirect_to edit_dashboard_product_path(product), notice: "Variant deleted" }
      format.turbo_stream { render turbo_stream: turbo_stream.remove("variant_row_#{@variant.id}") }
    end
  end

  private

  def set_variant
    @variant = ProductVariant.find(params[:id])
  end

  def variant_params
    params.require(:product_variant).permit(
      :price,
      :sku,
      :stock,
      :active
    )
  end
end
