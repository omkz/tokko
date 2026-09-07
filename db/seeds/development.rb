# Development-only demo data. Safe to rerun: shared reference data
# (admin, categories, filters, collections) uses find_or_create_by!, and the
# demo product catalog is only created once (see the Product.exists? guard
# below) so it never overwrites developer-created products.

puts "Creating development demo data..."

admin = User.find_or_create_by!(email_address: "admin@tokko.com") do |user|
  user.password = "password"
  user.role = :admin
end
puts admin.previously_new_record? ? "Created demo admin." : "Demo admin already exists."

CATEGORY_NAMES = %w[Tops Bottoms Outerwear Shoes].freeze

categories = CATEGORY_NAMES.index_with { |name| Category.find_or_create_by!(name: name) }

FILTER_DEFINITIONS = {
  "Gender" => %w[Men Women Unisex],
  "Brand" => %w[Zara Uniqlo H&M],
  "Material" => %w[Cotton Leather Denim]
}.freeze

filter_options = FILTER_DEFINITIONS.each_with_object({}) do |(group_name, values), by_group|
  group = FilterGroup.find_or_create_by!(name: group_name) do |filter_group|
    filter_group.position = FILTER_DEFINITIONS.keys.index(group_name) + 1
  end

  by_group[group_name] = values.each_with_object({}) do |value, by_value|
    by_value[value] = group.filter_options.find_or_create_by!(value: value) do |filter_option|
      filter_option.position = values.index(value) + 1
    end
  end
end

COLLECTION_DEFINITIONS = [
  { name: "Summer Collection", description: "Bright and airy essentials for the sunny days." },
  { name: "Winter Essentials", description: "Stay warm and cozy with our premium winter gear." }
].freeze

collections = COLLECTION_DEFINITIONS.each_with_object({}) do |attrs, by_name|
  by_name[attrs[:name]] = Collection.find_or_create_by!(name: attrs[:name]) do |collection|
    collection.description = attrs[:description]
    collection.active = true
  end
end

puts "Created reference catalog data."

CLOTHING_OPTIONS = { "Size" => %w[S M L XL], "Color" => %w[Black White Navy] }.freeze
SHOE_OPTIONS     = { "Size" => %w[39 40 41 42], "Color" => %w[Black White] }.freeze

DEMO_PRODUCTS = [
  # Tops
  { sku_prefix: "CCT", name: "Classic Cotton Tee", category: "Tops",
    description: "Soft everyday cotton tee with a relaxed fit.",
    gender: "Unisex", material: "Cotton", brand: "Uniqlo",
    collections: [ "Summer Collection" ], options: CLOTHING_OPTIONS, price: 29, stock: 40 },
  { sku_prefix: "ROX", name: "Relaxed Oxford Shirt", category: "Tops",
    description: "Breathable oxford weave shirt for warm-weather layering.",
    gender: "Men", material: "Cotton", brand: "Zara",
    collections: [ "Summer Collection" ], options: CLOTHING_OPTIONS, price: 49, stock: 30 },
  { sku_prefix: "ECS", name: "Everyday Crew Sweatshirt", category: "Tops",
    description: "Heavyweight crewneck sweatshirt for cool mornings.",
    gender: "Unisex", material: "Cotton", brand: "H&M",
    collections: [ "Winter Essentials" ], options: CLOTHING_OPTIONS, price: 45, stock: 35 },
  { sku_prefix: "SFP", name: "Slim Fit Polo", category: "Tops",
    description: "Tailored polo shirt with a clean, slim silhouette.",
    gender: "Men", material: "Cotton", brand: "Uniqlo",
    collections: [], options: CLOTHING_OPTIONS, price: 39, stock: 30 },
  { sku_prefix: "LBT", name: "Linen Blend Tank", category: "Tops",
    description: "Lightweight linen blend tank for hot days.",
    gender: "Women", material: "Cotton", brand: "Zara",
    collections: [ "Summer Collection" ], options: CLOTHING_OPTIONS, price: 25, stock: 25 },
  { sku_prefix: "GPT", name: "Graphic Print Tee", category: "Tops",
    description: "Cotton tee with a bold front graphic print.",
    gender: "Unisex", material: "Cotton", brand: "H&M",
    collections: [], options: CLOTHING_OPTIONS, price: 29, stock: 45 },

  # Bottoms
  { sku_prefix: "DSJ", name: "Denim Straight Jeans", category: "Bottoms",
    description: "Straight leg jeans in classic mid-wash denim.",
    gender: "Men", material: "Denim", brand: "Zara",
    collections: [], options: CLOTHING_OPTIONS, price: 69, stock: 25 },
  { sku_prefix: "HSJ", name: "High-Waist Skinny Jeans", category: "Bottoms",
    description: "High-waist skinny jeans with stretch denim.",
    gender: "Women", material: "Denim", brand: "H&M",
    collections: [], options: CLOTHING_OPTIONS, price: 59, stock: 25 },
  { sku_prefix: "TCP", name: "Tailored Chino Pants", category: "Bottoms",
    description: "Smart-casual chinos in a tailored fit.",
    gender: "Men", material: "Cotton", brand: "Uniqlo",
    collections: [], options: CLOTHING_OPTIONS, price: 49, stock: 20 },
  { sku_prefix: "PMS", name: "Pleated Midi Skirt", category: "Bottoms",
    description: "Flowing pleated midi skirt for warm days.",
    gender: "Women", material: "Cotton", brand: "Zara",
    collections: [ "Summer Collection" ], options: CLOTHING_OPTIONS, price: 55, stock: 20 },
  { sku_prefix: "CUP", name: "Cargo Utility Pants", category: "Bottoms",
    description: "Utility cargo pants with multiple pockets.",
    gender: "Unisex", material: "Cotton", brand: "H&M",
    collections: [], options: CLOTHING_OPTIONS, price: 59, stock: 20 },
  { sku_prefix: "WLT", name: "Wide-Leg Trousers", category: "Bottoms",
    description: "Relaxed wide-leg trousers with a high waist.",
    gender: "Women", material: "Cotton", brand: "Uniqlo",
    collections: [], options: CLOTHING_OPTIONS, price: 55, stock: 20 },

  # Outerwear
  { sku_prefix: "LBJ", name: "Leather Biker Jacket", category: "Outerwear",
    description: "Classic biker jacket in genuine leather.",
    gender: "Men", material: "Leather", brand: "Zara",
    collections: [ "Winter Essentials" ], options: CLOTHING_OPTIONS, price: 149, stock: 12 },
  { sku_prefix: "DTJ", name: "Denim Trucker Jacket", category: "Outerwear",
    description: "Timeless trucker jacket in washed denim.",
    gender: "Unisex", material: "Denim", brand: "H&M",
    collections: [], options: CLOTHING_OPTIONS, price: 89, stock: 18 },
  { sku_prefix: "QPV", name: "Quilted Puffer Vest", category: "Outerwear",
    description: "Lightweight quilted vest for layering in the cold.",
    gender: "Women", material: "Cotton", brand: "Uniqlo",
    collections: [ "Winter Essentials" ], options: CLOTHING_OPTIONS, price: 79, stock: 18 },
  { sku_prefix: "WBO", name: "Wool Blend Overcoat", category: "Outerwear",
    description: "Long overcoat in a warm wool blend.",
    gender: "Men", material: "Cotton", brand: "Zara",
    collections: [ "Winter Essentials" ], options: CLOTHING_OPTIONS, price: 179, stock: 10 },
  { sku_prefix: "CBJ", name: "Cotton Bomber Jacket", category: "Outerwear",
    description: "Casual bomber jacket in brushed cotton.",
    gender: "Unisex", material: "Cotton", brand: "H&M",
    collections: [], options: CLOTHING_OPTIONS, price: 79, stock: 20 },
  { sku_prefix: "STJ", name: "Suede Trucker Jacket", category: "Outerwear",
    description: "Trucker jacket in soft suede leather.",
    gender: "Women", material: "Leather", brand: "Uniqlo",
    collections: [], options: CLOTHING_OPTIONS, price: 149, stock: 12 },

  # Shoes
  { sku_prefix: "LES", name: "Leather Everyday Sneaker", category: "Shoes",
    description: "Minimalist leather sneaker for daily wear.",
    gender: "Unisex", material: "Leather", brand: "Zara",
    collections: [], options: SHOE_OPTIONS, price: 99, stock: 24 },
  { sku_prefix: "CCS", name: "Classic Canvas Sneaker", category: "Shoes",
    description: "Lightweight canvas sneaker for warm-weather wear.",
    gender: "Unisex", material: "Cotton", brand: "Uniqlo",
    collections: [ "Summer Collection" ], options: SHOE_OPTIONS, price: 49, stock: 30 },
  { sku_prefix: "CLB", name: "Chelsea Leather Boot", category: "Shoes",
    description: "Pull-on Chelsea boot in polished leather.",
    gender: "Men", material: "Leather", brand: "H&M",
    collections: [ "Winter Essentials" ], options: SHOE_OPTIONS, price: 149, stock: 12 },
  { sku_prefix: "SDB", name: "Suede Desert Boot", category: "Shoes",
    description: "Classic desert boot in soft suede.",
    gender: "Men", material: "Leather", brand: "Zara",
    collections: [], options: SHOE_OPTIONS, price: 129, stock: 15 },
  { sku_prefix: "RPS", name: "Running Performance Shoe", category: "Shoes",
    description: "Breathable mesh running shoe for daily training.",
    gender: "Unisex", material: "Cotton", brand: "Uniqlo",
    collections: [], options: SHOE_OPTIONS, price: 119, stock: 20 },
  { sku_prefix: "SBH", name: "Strappy Block Heel", category: "Shoes",
    description: "Strappy block heel sandal for summer evenings.",
    gender: "Women", material: "Leather", brand: "H&M",
    collections: [ "Summer Collection" ], options: SHOE_OPTIONS, price: 89, stock: 18 }
].freeze

if Product.exists?
  puts "Development catalog already contains products; skipping demo product creation."
else
  DEMO_PRODUCTS.each do |attrs|
    product = Product.create!(
      name: attrs[:name],
      description: attrs[:description],
      category: categories.fetch(attrs[:category]),
      status: :active
    )

    product.filter_options << filter_options.fetch("Gender").fetch(attrs[:gender])
    product.filter_options << filter_options.fetch("Material").fetch(attrs[:material])
    product.filter_options << filter_options.fetch("Brand").fetch(attrs[:brand])

    attrs[:collections].each do |collection_name|
      product.collections << collections.fetch(collection_name)
    end

    attrs[:options].each_with_index do |(option_name, values), option_index|
      option = product.product_options.create!(name: option_name, position: option_index + 1)
      values.each_with_index do |value, value_index|
        option.product_option_values.create!(value: value, position: value_index + 1)
      end
    end

    product.generate_variants!

    product.product_variants.each do |variant|
      option_values = variant.product_option_values
                              .joins(:product_option)
                              .order("product_options.position")
                              .pluck(:value)

      variant.update!(
        price: attrs[:price],
        stock: attrs[:stock],
        sku: "TK-#{attrs[:sku_prefix]}-#{option_values.join('-')}".upcase
      )
    end
  end

  puts "Created #{DEMO_PRODUCTS.size} demo products."
end

puts "Done."
