class Dashboard::FilterOptionsController < Dashboard::BaseController
  before_action :set_filter_group, only: [:create]
  before_action :set_filter_option, only: [:destroy]

  def create
    @filter_option = @filter_group.filter_options.build(filter_option_params)
    @filter_option.position = @filter_group.filter_options.count + 1

    if @filter_option.save
      redirect_to edit_dashboard_filter_group_path(@filter_group), notice: "Option added."
    else
      redirect_to edit_dashboard_filter_group_path(@filter_group), alert: @filter_option.errors.full_messages.to_sentence
    end
  end

  def destroy
    filter_group = @filter_option.filter_group
    @filter_option.destroy
    redirect_to edit_dashboard_filter_group_path(filter_group), notice: "Option removed."
  end

  private

  def set_filter_group
    @filter_group = FilterGroup.find(params[:filter_group_id])
  end

  def set_filter_option
    @filter_option = FilterOption.find(params[:id])
  end

  def filter_option_params
    params.require(:filter_option).permit(:value, :slug, :position)
  end
end
