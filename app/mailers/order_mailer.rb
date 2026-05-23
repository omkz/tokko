class OrderMailer < ApplicationMailer
  def confirmation(order)
    @order = order
    @items = order.order_items.includes(product_variant: :product)

    mail(
      to: order.customer_email,
      subject: "Order Confirmed ##{order.id}"
    )
  end
end
