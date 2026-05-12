puts "🧹 Cleaning up database..."
Session.destroy_all
User.destroy_all
Product.destroy_all

puts "👤 Creating default users..."
# Create the main Owner account
owner = User.create!(
  email_address: "owner@tokko.com",
  password: "password123",
  role: :owner
)
puts "➡️ Created Owner: #{owner.email_address} (password: password123)"

# Create an Admin account
admin = User.create!(
  email_address: "admin@tokko.com",
  password: "password123",
  role: :admin
)
puts "➡️ Created Admin: #{admin.email_address} (password: password123)"

# Create a Staff account
staff = User.create!(
  email_address: "staff@tokko.com",
  password: "password123",
  role: :staff
)
puts "➡️ Created Staff: #{staff.email_address} (password: password123)"

puts "🌱 Seeding products..."

# --- PRODUCT 1: Classic T-Shirt ---
puts "➡️ Creating Classic T-Shirt..."
p1 = Product.create!(
  name: "Classic Heavyweight T-Shirt",
  description: "Kaos polos bahan cotton combed 20s. Sangat nyaman dan awet untuk dipakai sehari-hari.",
  slug: "classic-heavyweight-t-shirt",
  status: "active"
)

p1.product_options.create!(name: "Size", product_option_values_attributes: [
  { value: "S", position: 1 },
  { value: "M", position: 2 },
  { value: "L", position: 3 },
  { value: "XL", position: 4 }
])

p1.product_options.create!(name: "Color", product_option_values_attributes: [
  { value: "Black", position: 1 },
  { value: "White", position: 2 },
  { value: "Navy", position: 3 }
])

p1.generate_variants!

# Update some prices & stock for realism
p1.product_variants.each do |v|
  # XL is a bit more expensive
  price = v.option_text.include?("XL") ? 125000 : 100000
  v.update!(price: price, stock: rand(10..50))
end


# --- PRODUCT 2: Sneakers ---
puts "➡️ Creating Urban Sneakers..."
p2 = Product.create!(
  name: "Urban Explorer Sneakers",
  description: "Sepatu casual cocok untuk jalan-jalan keliling kota. Sol empuk dan anti-slip.",
  slug: "urban-explorer-sneakers",
  status: "active"
)

p2.product_options.create!(name: "Size (EU)", product_option_values_attributes: [
  { value: "40", position: 1 },
  { value: "41", position: 2 },
  { value: "42", position: 3 },
  { value: "43", position: 4 },
  { value: "44", position: 5 }
])

p2.generate_variants!

p2.product_variants.each do |v|
  v.update!(price: 450000, stock: rand(5..20))
end


# --- PRODUCT 3: Tote Bag (No variants) ---
puts "➡️ Creating Canvas Tote Bag..."
p3 = Product.create!(
  name: "Eco Canvas Tote Bag",
  description: "Tas tote bag bahan kanvas tebal ramah lingkungan. Cocok untuk belanja atau kuliah.",
  slug: "eco-canvas-tote-bag",
  status: "active"
)
# Just update the default variant
p3.product_variants.first.update!(price: 50000, stock: 100)


# --- PRODUCT 4: Draft Product ---
puts "➡️ Creating Draft Product..."
Product.create!(
  name: "Winter Jacket (Coming Soon)",
  description: "Jaket musim dingin tahan air.",
  slug: "winter-jacket",
  status: "draft"
)

puts "📦 Seeding orders..."
o1 = Order.create!(
  customer_name: "John Doe",
  customer_email: "john@example.com",
  customer_phone: "08123456789",
  shipping_address: "Jl. Merdeka No. 123, Jakarta",
  total_price: 250000,
  status: :paid
)
o1.order_items.create!(product_variant: p1.product_variants.first, quantity: 2, unit_price: 125000)

o2 = Order.create!(
  customer_name: "Jane Smith",
  customer_email: "jane@example.com",
  customer_phone: "08987654321",
  shipping_address: "Apartemen Sudirman, Tower A-10, Jakarta",
  total_price: 450000,
  status: :pending
)
o2.order_items.create!(product_variant: p2.product_variants.first, quantity: 1, unit_price: 450000)

puts "✅ Seeding complete!"
puts "📊 Total Users: #{User.count}"
puts "📊 Total Products: #{Product.count}"
puts "📊 Total Variants: #{ProductVariant.count}"
puts "📊 Total Orders: #{Order.count}"
puts "🚀 You can now login with: admin@tokko.com / password123"
