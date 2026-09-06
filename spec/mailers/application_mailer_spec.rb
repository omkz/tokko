require "rails_helper"

RSpec.describe ApplicationMailer do
  around do |example|
    original = ENV["MAIL_FROM"]
    example.run
  ensure
    ENV["MAIL_FROM"] = original
  end

  it "defaults the from address when MAIL_FROM is not set" do
    ENV.delete("MAIL_FROM")
    order = create(:order)

    mail = OrderMailer.confirmation(order)

    expect(mail.from).to eq([ "no-reply@example.com" ])
  end

  it "honors MAIL_FROM when set" do
    ENV["MAIL_FROM"] = "no-reply@shop.example.com"
    order = create(:order)

    mail = OrderMailer.confirmation(order)

    expect(mail.from).to eq([ "no-reply@shop.example.com" ])
  end
end
