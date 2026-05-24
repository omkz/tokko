class Dashboard::ProductsController < Dashboard::BaseController
  before_action :set_product, only: %i[ show edit update destroy ]

  # GET /dashboard/products
  def index
    # Use the search scope we defined in Product model
    @products = Product.includes(:product_variants, :collections).search(params[:q])
    @pagy, @products = pagy(@products.order(created_at: :desc))
  end

  # GET /dashboard/products/1
  def show
  end

  # GET /dashboard/products/new
  def new
    @product = Product.new
  end

  # GET /dashboard/products/1/edit
  def edit
    @filter_groups = FilterGroup.ordered.includes(:filter_options)
  end

  # POST /dashboard/products
  def create
    @product = Product.new(product_params)

    if @product.save
      redirect_to dashboard_products_path, notice: "Product was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /dashboard/products/1
  def update
    if @product.update(product_params)
      redirect_to dashboard_products_path, notice: "Product was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /dashboard/products/1
  def destroy
    @product.destroy
    redirect_to dashboard_products_path, notice: "Product was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_product
      @product = Product.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def product_params
      params.require(:product).permit(:name, :description, :slug, images: [], collection_ids: [], filter_option_ids: [])
    end
end
