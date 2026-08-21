require "rails_helper"

RSpec.describe Coupon, type: :model do
  describe "#usage_count" do
    it "counts only paid, shipped, and completed orders" do
      coupon = create(:coupon)
      create(:order, coupon: coupon, status: :pending)
      create(:order, coupon: coupon, status: :cancelled)
      create(:order, coupon: coupon, status: :paid)
      create(:order, coupon: coupon, status: :shipped)
      create(:order, coupon: coupon, status: :completed)

      expect(coupon.usage_count).to eq(3)
    end
  end

  describe "#valid_for_use?" do
    it "counts pending orders toward the usage limit" do
      coupon = create(:coupon, usage_limit: 1)
      create(:order, coupon: coupon, status: :pending)

      expect(coupon).not_to be_valid_for_use
      expect(coupon.usage_count).to eq(0)
    end

    it "becomes available when a pending order is cancelled" do
      coupon = create(:coupon, usage_limit: 1)
      order = create(:order, coupon: coupon, status: :pending)

      order.update!(status: :cancelled)

      expect(coupon).to be_valid_for_use
    end

    it "is invalid when expired" do
      coupon = create(:coupon, expires_at: 1.minute.ago)

      expect(coupon).not_to be_valid_for_use
    end

    it "is invalid when inactive" do
      coupon = create(:coupon, active: false)

      expect(coupon).not_to be_valid_for_use
    end

    it "is invalid when successful usage reaches the limit" do
      coupon = create(:coupon, usage_limit: 1)
      create(:order, coupon: coupon, status: :paid)

      expect(coupon).not_to be_valid_for_use
    end

    it "ignores cancelled orders when enforcing the limit" do
      coupon = create(:coupon, usage_limit: 1)
      create(:order, coupon: coupon, status: :cancelled)

      expect(coupon).to be_valid_for_use
    end
  end
end
