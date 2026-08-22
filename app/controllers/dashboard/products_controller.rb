class Dashboard::ProductsController < Dashboard::BaseController
  before_action :set_product, only: %i[ show edit update destroy ]

  def index
    @products = Product.includes(:product_variants, :collections).search(params[:q])
    @pagy, @products = pagy(@products.order(created_at: :desc))
  end

  def show
  end

  def new
    @product = Product.new
  end

  def edit
    @filter_groups = FilterGroup.ordered.includes(:filter_options)
  end

  def create
    @product = Product.new(product_params)

    if @product.save
      redirect_to edit_dashboard_product_path(@product), notice: "Product created. Now add images, options, and variants."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @product.update(product_params)
      redirect_to dashboard_products_path, notice: "Product was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    result = @product.destroy_or_archive!
    notice = if result == :destroyed
      "Product deleted"
    else
      "Product has order history and has been archived instead"
    end

    redirect_to dashboard_products_path, notice: notice, status: :see_other
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:name, :description, :slug, :category_id, images: [], collection_ids: [], filter_option_ids: [])
  end
end
