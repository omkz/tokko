require "rails_helper"

RSpec.describe Category, type: :model do
  describe "#self_and_descendant_ids" do
    it "returns only itself when it has no children" do
      category = create(:category)

      expect(category.self_and_descendant_ids).to eq([ category.id ])
    end

    it "returns itself and every descendant" do
      root = create(:category)
      child_a = create(:category, parent: root)
      child_b = create(:category, parent: root)
      grandchild = create(:category, parent: child_a)

      expect(root.self_and_descendant_ids).to contain_exactly(
        root.id,
        child_a.id,
        child_b.id,
        grandchild.id
      )
    end

    it "excludes ancestors, siblings, and unrelated branches" do
      root = create(:category)
      child_a = create(:category, parent: root)
      child_b = create(:category, parent: root)
      grandchild = create(:category, parent: child_a)
      unrelated = create(:category)

      expect(child_a.self_and_descendant_ids).to contain_exactly(child_a.id, grandchild.id)
      expect(child_a.self_and_descendant_ids).not_to include(root.id, child_b.id, unrelated.id)
    end

    it "uses one query regardless of tree depth" do
      Prosopite.pause
      root = create(:category)
      6.times.reduce(root) { |parent, _| create(:category, parent: parent) }
      Prosopite.resume
      queries = []

      subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
        next if payload[:cached]
        next if payload[:name] == "SCHEMA"
        next if payload[:sql].match?(/\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/)

        queries << payload[:sql]
      end

      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        root.self_and_descendant_ids
      end

      expect(queries.size).to eq(1)
    end
  end

  describe "Product.in_category" do
    it "includes products from the category and all descendants only" do
      root = create(:category)
      child = create(:category, parent: root)
      grandchild = create(:category, parent: child)
      unrelated = create(:category)
      root_product = create(:product, category: root)
      child_product = create(:product, category: child)
      grandchild_product = create(:product, category: grandchild)
      unrelated_product = create(:product, category: unrelated)

      expect(Product.in_category(root).pluck(:id)).to contain_exactly(
        root_product.id,
        child_product.id,
        grandchild_product.id
      )
      expect(Product.in_category(root)).not_to include(unrelated_product)
    end
  end
end
