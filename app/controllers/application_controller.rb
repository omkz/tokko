class ApplicationController < ActionController::Base
  include Pagy::Method
  include Authentication
  include CartManagement

  allow_browser versions: :modern

  stale_when_importmap_changes

  unless Rails.env.production?
    around_action :n_plus_one_detection

    def n_plus_one_detection
      Prosopite.scan
      yield
    ensure
      Prosopite.finish
    end
  end

  before_action :resume_session
  before_action :set_nav_data
  before_action :set_error_context

  private

  def set_nav_data
    @nav_categories = Category.roots.ordered.includes(:children)
    @nav_collections = Collection.featured_for_nav
  end

  # Privacy-minimal by design: no params, user identity, or customer data.
  def set_error_context
    Rails.error.set_context(
      request_id: request.request_id,
      controller: controller_name,
      action: action_name
    )
  end
end
