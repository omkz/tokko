puts "Clearing existing data..."
CollectionMembership.delete_all
Collection.delete_all
OrderItem.delete_all
Order.delete_all
VariantOptionValue.delete_all
ProductVariant.delete_all
ProductOptionValue.delete_all
ProductOption.delete_all
ProductFilterOption.delete_all
FilterOption.delete_all
FilterGroup.delete_all
Product.delete_all
Category.delete_all
User.delete_all if defined?(User)

puts "Creating Admin User..."
admin = User.find_or_create_by!(email_address: "admin@tokko.com") do |user|
  user.password = "password"
  user.role = :admin
end

puts "Creating Categories (Taxonomy) for Fashion Store..."
tops = Category.create!(name: "Tops")
bottoms = Category.create!(name: "Bottoms")
outerwear = Category.create!(name: "Outerwear")
shoes = Category.create!(name: "Shoes")

categories = [tops, bottoms, outerwear, shoes]

puts "Creating Filter Groups & Options (Facets)..."
gender_filter = FilterGroup.create!(name: "Gender", position: 1)
men_opt = gender_filter.filter_options.create!(value: "Men", position: 1)
women_opt = gender_filter.filter_options.create!(value: "Women", position: 2)
unisex_opt = gender_filter.filter_options.create!(value: "Unisex", position: 3)

brand_filter = FilterGroup.create!(name: "Brand", position: 2)
zara_opt = brand_filter.filter_options.create!(value: "Zara", position: 1)
uniqlo_opt = brand_filter.filter_options.create!(value: "Uniqlo", position: 2)
hm_opt = brand_filter.filter_options.create!(value: "H&M", position: 3)

material_filter = FilterGroup.create!(name: "Material", position: 3)
cotton_opt = material_filter.filter_options.create!(value: "Cotton", position: 1)
leather_opt = material_filter.filter_options.create!(value: "Leather", position: 2)
denim_opt = material_filter.filter_options.create!(value: "Denim", position: 3)

puts "Creating Collections..."
collections = [
  { name: "Summer Collection", description: "Bright and airy essentials for the sunny days." },
  { name: "Winter Essentials", description: "Stay warm and cozy with our premium winter gear." }
].map { |c| Collection.create!(c.merge(active: true)) }

puts "Creating 100 Fashion Products without images..."
100.times do |i|
  cat = categories.sample
  
  product = Product.create!(
    name: "Premium #{cat.name} #{i+1}",
    description: "High quality #{cat.name.downcase} designed for everyday use. Comfortable to wear all day.",
    category: cat,
    status: :active
  )

  # Assign Filters
  product.filter_options << [men_opt, women_opt, unisex_opt].sample
  product.filter_options << [cotton_opt, leather_opt, denim_opt].sample
  product.filter_options << [zara_opt, uniqlo_opt, hm_opt].sample

  # Assign Collections
  product.collections << collections.sample(rand(0..2))

  # Add Product Options (For Variants)
  if cat == shoes
    size_opt = product.product_options.create!(name: "Size", position: 1)
    ["39", "40", "41", "42"].each_with_index { |s, idx| size_opt.product_option_values.create!(value: s, position: idx + 1) }
  else
    size_opt = product.product_options.create!(name: "Size", position: 1)
    ["S", "M", "L", "XL"].each_with_index { |s, idx| size_opt.product_option_values.create!(value: s, position: idx + 1) }
  end
  
  color_opt = product.product_options.create!(name: "Color", position: 2)
  ["Black", "White", "Navy"].each_with_index { |c, idx| color_opt.product_option_values.create!(value: c, position: idx + 1) }

  product.generate_variants!
  
  product.product_variants.each do |v|
    v.update!(price: rand(150..500) * 1000, stock: rand(10..100), sku: "TK-#{product.id}-#{v.id}")
  end
end

puts "\nDone! Seeded Fashion Categories, Facets, and 100 fashion products."
