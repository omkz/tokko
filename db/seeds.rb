puts "Clearing existing data..."
CollectionMembership.delete_all
Collection.delete_all
OrderItem.delete_all
Order.delete_all
VariantOptionValue.delete_all
ProductVariant.delete_all
ProductOptionValue.delete_all
ProductOption.delete_all
Product.delete_all

puts "Creating Collections..."
collections = [
  { name: "Summer Collection", description: "Bright and airy essentials for the sunny days." },
  { name: "Winter Essentials", description: "Stay warm and cozy with our premium winter gear." },
  { name: "Limited Edition", description: "Exclusive drops you won't find anywhere else." },
  { name: "Best Sellers", description: "The products everyone is talking about." },
  { name: "New Arrivals", description: "Freshly added to our curated catalog." }
].map { |c| Collection.create!(c.merge(active: true)) }

puts "Creating 1000 Products (this may take a minute)..."
categories = ["T-Shirt", "Hoodie", "Pants", "Cap", "Jacket", "Sneakers", "Bag", "Watch"]
colors = ["Black", "White", "Navy", "Grey", "Olive", "Maroon"]
sizes = ["S", "M", "L", "XL"]

# We'll use a small pool of placeholder images to avoid downloading 1000 times
image_urls = [
  "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?q=80&w=1000&auto=format&fit=crop", # White Tee
  "https://images.unsplash.com/photo-1556821840-3a63f95609a7?q=80&w=1000&auto=format&fit=crop", # Hoodie
  "https://images.unsplash.com/photo-1542272604-787c3835535d?q=80&w=1000&auto=format&fit=crop", # Jeans
  "https://images.unsplash.com/photo-1523275335684-37898b6baf30?q=80&w=1000&auto=format&fit=crop", # Watch
  "https://images.unsplash.com/photo-1527719327859-c6ce80353573?q=80&w=1000&auto=format&fit=crop", # Sneakers
  "https://images.unsplash.com/photo-1584917865442-de89df76afd3?q=80&w=1000&auto=format&fit=crop"  # Bag
]

# Create some cached downloads
require "open-uri"
downloaded_images = image_urls.map do |url|
  { io: URI.open(url), filename: File.basename(URI.parse(url).path) }
end

1000.times do |i|
  category = categories.sample
  name = "#{category} #{Faker::Appliance.equipment} #{i+1}"
  
  product = Product.create!(
    name: name,
    description: Faker::Lorem.paragraph(sentence_count: 5),
    slug: "#{name.parameterize}-#{i}"
  )

  # Attach one random image from our pool
  img = downloaded_images.sample
  product.images.attach(io: File.open(img[:io].path), filename: img[:filename])

  # Add to random collections
  product.collections << collections.sample(rand(1..3))

  # Add Options
  size_opt = product.product_options.create!(name: "Size", position: 1)
  sizes.each_with_index { |s, idx| size_opt.product_option_values.create!(value: s, position: idx + 1) }

  color_opt = product.product_options.create!(name: "Color", position: 2)
  colors.sample(3).each_with_index { |c, idx| color_opt.product_option_values.create!(value: c, position: idx + 1) }

  # Generate variants
  product.generate_variants!
  
  # Set prices and stock for variants
  product.product_variants.each do |v|
    v.update!(
      price: rand(150..950) * 1000,
      stock: rand(10..100),
      sku: "TK-#{product.id}-#{v.id}"
    )
  end

  print "." if (i + 1) % 50 == 0
end

puts "\nCreating sample Orders..."
25.times do |i|
  order = Order.create!(
    customer_name: Faker::Name.name,
    customer_email: Faker::Internet.email,
    customer_phone: Faker::PhoneNumber.phone_number,
    shipping_address: Faker::Address.full_address,
    status: Order.statuses.keys.sample,
    total_price: 0,
    created_at: rand(0..7).days.ago
  )

  # Add 1-3 random items
  rand(1..3).times do
    variant = ProductVariant.all.sample
    quantity = rand(1..2)
    order.order_items.create!(
      product_variant: variant,
      quantity: quantity,
      unit_price: variant.price
    )
    order.update!(total_price: order.total_price + (variant.price * quantity))
  end
end

puts "\nDone! Seeded 1000 products, 5 collections, and 25 orders."
