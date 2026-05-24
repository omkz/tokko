class Dashboard::BaseController < ApplicationController
  before_action :require_authentication
  before_action :require_dashboard_access
  layout "dashboard"

  private

  def require_dashboard_access
    redirect_to root_path, alert: "Not authorized." unless Current.user&.dashboard_access?
  end
end
