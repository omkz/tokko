class Dashboard::ProductsController < Dashboard::BaseController
  before_action :set_product, only: %i[show edit update destroy generate_variants delete_image]

  def index
    @products = Product.includes(:product_variants).order(created_at: :desc)
  end

  def show
    @variants = @product.product_variants.includes(:product_option_values)
  end

  def new
    @product = Product.new
  end

  def create
    @product = Product.new(product_params)

    if @product.save
      redirect_to edit_dashboard_product_path(@product),
                  notice: "Product created. Now add options and variants."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @product = Product.includes(
      product_options: :product_option_values,
      product_variants: :product_option_values
    ).find(params[:id])
  end

  def update
    if @product.update(product_params)
      redirect_to edit_dashboard_product_path(@product),
                  notice: "Product saved"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product.destroy
    redirect_to dashboard_products_path, notice: "Product deleted"
  end

  def generate_variants
    @product.generate_variants!
    redirect_to edit_dashboard_product_path(@product),
                notice: "Variants generated (#{@product.product_variants.count} total)"
  end

  def delete_image
    image = ActiveStorage::Attachment.find(params[:image_id])
    image.purge
    
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("image_#{image.id}") }
      format.html { redirect_to edit_dashboard_product_path(image.record), notice: "Image deleted" }
    end
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    params.require(:product).permit(
      :name,
      :slug,
      :description,
      :status,
      images: []
    )
  end
end
