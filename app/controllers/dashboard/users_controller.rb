class Dashboard::UsersController < Dashboard::BaseController
  before_action :require_owner, only: :update

  def index
    @pagy, @users = pagy(User.order(created_at: :desc))
  end

  def update
    @user = User.find(params[:id])

    if @user == Current.user
      redirect_to dashboard_users_path, alert: "You cannot change your own role."
      return
    end

    if @user.update(role: params[:user][:role])
      redirect_to dashboard_users_path, notice: "Role updated."
    else
      redirect_to dashboard_users_path, alert: "Failed to update role."
    end
  end

  private

  def require_owner
    redirect_to dashboard_users_path, alert: "Not authorized." unless Current.user&.owner?
  end
end
