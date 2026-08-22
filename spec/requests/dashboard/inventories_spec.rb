require "rails_helper"

RSpec.describe "Dashboard inventories", type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    post session_path, params: { email_address: admin.email_address, password: "password123" }
  end

  describe "PATCH /dashboard/inventory/update_all" do
    it "updates multiple variants through adjustment movements" do
      first_variant = create(:product_variant, stock: 5)
      second_variant = create(:product_variant, stock: 10)

      expect {
        patch dashboard_inventory_update_all_path, params: {
          variants: {
            first_variant.id => { stock: 8 },
            second_variant.id => { stock: 4 }
          },
          q: "shirt",
          page: 2
        }
      }.to change(InventoryMovement.adjustment, :count).by(2)

      expect(first_variant.reload.stock).to eq(8)
      expect(second_variant.reload.stock).to eq(4)
      expect(response).to redirect_to(dashboard_inventory_path(q: "shirt", page: 2))
      expect(flash[:notice]).to eq("Updated inventory for 2 variants.")
    end

    it "records the stock delta and current user for each movement" do
      variant = create(:product_variant, stock: 7)

      patch dashboard_inventory_update_all_path, params: {
        variants: { variant.id => { stock: 12 } }
      }

      movement = InventoryMovement.adjustment.find_by!(product_variant: variant)
      expect(movement).to have_attributes(
        quantity: 5,
        user: admin,
        note: "Manual adjustment via dashboard"
      )
    end

    it "does not create a movement when stock is unchanged" do
      variant = create(:product_variant, stock: 7)

      expect {
        patch dashboard_inventory_update_all_path, params: {
          variants: { variant.id => { stock: 7 } }
        }
      }.not_to change(InventoryMovement, :count)

      expect(flash[:notice]).to eq("Updated inventory for 0 variants.")
    end

    it "loads and locks all submitted variants with one query" do
      variants = create_list(:product_variant, 3, stock: 5)
      queries = []

      subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
        next if payload[:cached] || payload[:name] == "SCHEMA"
        next unless payload[:sql].match?(/\ASELECT .*\bFROM \"product_variants\"/m)

        queries << payload[:sql]
      end

      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        patch dashboard_inventory_update_all_path, params: {
          variants: variants.index_with { |variant| { stock: variant.stock + 1 } }
        }
      end

      expect(queries.one?).to be(true)
      expect(queries.first).to match(/\bFOR UPDATE\b/)
    end

    it "rolls back the whole batch when a later adjustment fails" do
      first_variant = create(:product_variant, stock: 5)
      second_variant = create(:product_variant, stock: 5)

      expect {
        patch dashboard_inventory_update_all_path, params: {
          variants: {
            first_variant.id => { stock: 8 },
            second_variant.id => { stock: -1 }
          }
        }
      }.to raise_error(ActiveRecord::StatementInvalid)

      expect(first_variant.reload.stock).to eq(5)
      expect(second_variant.reload.stock).to eq(5)
      expect(
        InventoryMovement.adjustment.where(product_variant: [ first_variant, second_variant ])
      ).to be_empty
    end

    it "fails when a submitted variant does not exist" do
      variant = create(:product_variant, stock: 5)
      unknown_id = ProductVariant.maximum(:id) + 1

      patch dashboard_inventory_update_all_path, params: {
        variants: {
          variant.id => { stock: 8 },
          unknown_id => { stock: 4 }
        }
      }

      expect(response).to have_http_status(:not_found)
      expect(variant.reload.stock).to eq(5)
      expect(InventoryMovement.adjustment.where(product_variant: variant)).to be_empty
    end
  end
end
