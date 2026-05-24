module CartManagement
  extend ActiveSupport::Concern

  included do
    helper_method :current_cart
  end

  private

  def current_cart
    @current_cart ||= find_cart
  end

  def find_cart
    if Current.user
      Cart.find_by(user: Current.user)
    elsif (token = cookies.signed[:cart_token]).present?
      Cart.find_by(token: token)
    end
  end

  def find_or_create_cart
    @current_cart = if Current.user
      Cart.find_or_create_by!(user: Current.user) do |c|
        c.expires_at = nil
      end
    else
      token = cookies.signed[:cart_token]
      cart = token.present? ? Cart.find_by(token: token) : nil
      unless cart
        cart = Cart.create!(expires_at: 30.days.from_now)
        cookies.signed.permanent[:cart_token] = { value: cart.token, httponly: true, same_site: :lax }
      end
      cart
    end
  end

  def merge_guest_cart_into_user(user)
    token = cookies.signed[:cart_token]
    return unless token.present?

    guest_cart = Cart.find_by(token: token)
    return unless guest_cart

    user_cart = Cart.find_by(user: user)
    if user_cart
      user_cart.merge_from(guest_cart)
    else
      guest_cart.update!(user: user, expires_at: nil)
    end

    cookies.delete(:cart_token)
    @current_cart = nil
  end
end
