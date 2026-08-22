class AddTrigramIndexesToProducts < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    add_index :products,
              :name,
              using: :gin,
              opclass: :gin_trgm_ops,
              algorithm: :concurrently,
              name: "index_products_on_name_trigram"

    add_index :products,
              :description,
              using: :gin,
              opclass: :gin_trgm_ops,
              algorithm: :concurrently,
              name: "index_products_on_description_trigram"
  end
end
