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

  private

  def set_nav_data
    @nav_categories = Category.roots.ordered.includes(:children)
    @nav_collections = Collection.featured_for_nav
  end
end
