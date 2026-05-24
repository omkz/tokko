class ApplicationController < ActionController::Base
  include Pagy::Method
  include Authentication
  include CartManagement
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
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

  private

  def set_nav_data
    @nav_categories = Category.roots.ordered.includes(:children)
    @nav_collections = Collection.featured_for_nav
  end
end
