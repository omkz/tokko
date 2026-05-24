class HomeController < ApplicationController
  allow_unauthenticated_access

  def index
    @collections = Collection.where(active: true)
                             .includes(products: [ :product_variants, { images_attachments: :blob } ])
  end
end
