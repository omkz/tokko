class AccountsController < ApplicationController
  def show
    @recent_orders = Order.includes(:order_items)
                          .where(customer_email: Current.user.email_address)
                          .order(created_at: :desc)
                          .limit(3)

    @wishlist_count = Current.user.wishlist_items.count
    @orders_count   = Order.where(customer_email: Current.user.email_address).count
  end

  def edit
  end

  def update
    if Current.user.update(account_params)
      redirect_to account_path, notice: "Profile updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def account_params
    params.require(:user).permit(:first_name, :last_name)
  end
end
