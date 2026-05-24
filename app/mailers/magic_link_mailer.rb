class MagicLinkMailer < ApplicationMailer
  def login(user, token)
    @user  = user
    @url   = magic_link_url(token: token)
    mail(to: @user.email_address, subject: "Your login link for Tokko")
  end
end
