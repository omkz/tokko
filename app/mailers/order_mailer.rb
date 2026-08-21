class OrderMailer < ApplicationMailer
  def confirmation(order)
    @order = order
    @items = order.order_items

    mail(
      to: order.customer_email,
      subject: "Order Confirmed ##{order.id}"
    )
  end
end
