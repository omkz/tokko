class ProductVariantsController < ApplicationController
  before_action :set_variant, only: %i[update destroy]

  # PATCH /product_variants/:id
  def update
    if @variant.update(variant_params)
      redirect_to edit_product_path(@variant.product),
                  notice: "Variant saved"
    else
      redirect_to edit_product_path(@variant.product),
                  alert: @variant.errors.full_messages.to_sentence
    end
  end

  # DELETE /product_variants/:id
  def destroy
    product = @variant.product
    @variant.destroy

    redirect_to edit_product_path(product),
                notice: "Variant deleted"
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
