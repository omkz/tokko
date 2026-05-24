class MagicLinksController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 1.minute, only: :create, with: -> { redirect_to new_magic_link_path, alert: "Too many requests. Try again later." }

  def new
  end

  def create
    user = User.find_or_create_by!(email_address: params[:email_address].strip.downcase)
    token = user.generate_token_for(:magic_link)
    MagicLinkMailer.login(user, token).deliver_later
    redirect_to new_magic_link_path, notice: "Check your email for a login link."
  rescue ActiveRecord::RecordInvalid
    redirect_to new_magic_link_path, alert: "Invalid email address."
  end

  def show
    user = User.find_by_token_for(:magic_link, params[:token])

    if user
      user.touch
      start_new_session_for(user)
      merge_guest_cart_into_user(user)
      redirect_to after_authentication_url, notice: "Welcome back!"
    else
      redirect_to new_magic_link_path, alert: "Link expired or invalid. Please request a new one."
    end
  end
end
