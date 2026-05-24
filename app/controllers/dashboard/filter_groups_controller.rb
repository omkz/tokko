class Dashboard::FilterGroupsController < Dashboard::BaseController
  before_action :set_filter_group, only: [:edit, :update, :destroy]

  def index
    @filter_groups = FilterGroup.ordered.includes(:filter_options)
  end

  def new
    @filter_group = FilterGroup.new
  end

  def create
    @filter_group = FilterGroup.new(filter_group_params)
    if @filter_group.save
      redirect_to dashboard_filter_groups_path, notice: "Filter group created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @filter_group = FilterGroup.includes(filter_options: :product_filter_options).find(params[:id])
  end

  def update
    if @filter_group.update(filter_group_params)
      redirect_to dashboard_filter_groups_path, notice: "Filter group updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @filter_group.destroy
    redirect_to dashboard_filter_groups_path, notice: "Filter group deleted."
  end

  private

  def set_filter_group
    @filter_group = FilterGroup.find(params[:id])
  end

  def filter_group_params
    params.require(:filter_group).permit(:name, :slug, :position)
  end
end
