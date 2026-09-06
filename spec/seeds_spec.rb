require "rails_helper"

RSpec.describe "db/seeds.rb" do
  it "creates no demo data outside of development" do
    expect(Rails.env.development?).to be(false)

    expect {
      load Rails.root.join("db/seeds.rb")
    }.not_to change(Product, :count)

    expect(User.exists?(email_address: "admin@tokko.com")).to be(false)
  end

  it "contains no destructive application-data cleanup" do
    seed_files = [
      Rails.root.join("db/seeds.rb"),
      Rails.root.join("db/seeds/development.rb")
    ]

    seed_files.each do |file|
      source = File.read(file)
      expect(source).not_to match(/\.(delete_all|destroy_all)\b/)
    end
  end
end
