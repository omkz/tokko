class Dashboard::CollectionsController < Dashboard::BaseController
  before_action :set_collection, only: %i[edit update destroy]

  def index
    @collections = Collection.all.order(created_at: :desc)
  end

  def new
    @collection = Collection.new
  end

  def create
    @collection = Collection.new(collection_params)
    if @collection.save
      redirect_to dashboard_collections_path, notice: "Collection created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @collection.update(collection_params)
      redirect_to dashboard_collections_path, notice: "Collection updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @collection.destroy
    redirect_to dashboard_collections_path, notice: "Collection deleted."
  end

  private

  def set_collection
    @collection = Collection.find(params[:id])
  end

  def collection_params
    params.require(:collection).permit(:name, :description, :active, product_ids: [])
  end
end
