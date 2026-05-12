class Dashboard::BaseController < ApplicationController
  before_action :require_authentication
  layout "dashboard"
end
