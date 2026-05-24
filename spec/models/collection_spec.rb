require 'rails_helper'

RSpec.describe Collection, type: :model do
  describe 'validations' do
    it 'is valid with a name and unique slug' do
      collection = Collection.new(name: 'Summer Sale')
      expect(collection).to be_valid
    end

    it 'is invalid without a name' do
      collection = Collection.new(name: nil)
      expect(collection).not_to be_valid
      expect(collection.errors[:name]).to include("can't be blank")
    end

    it 'enforces uniqueness of the slug' do
      Collection.create!(name: 'Summer Sale')
      duplicate = Collection.new(name: 'Summer Sale')

      # We trigger validation so the slug gets generated
      duplicate.valid?

      expect(duplicate.errors[:slug]).to include("has already been taken")
    end
  end

  describe '#generate_slug' do
    it 'parameterizes the name into a slug' do
      collection = Collection.new(name: 'New & Exclusive Arrivals!')
      collection.valid?
      expect(collection.slug).to eq('new-exclusive-arrivals')
    end

    it 'does not overwrite custom slug if name has not changed' do
      collection = Collection.create!(name: 'Summer Sale')
      collection.slug = 'custom-slug'
      collection.save!

      # Reload and save without changing name
      collection.reload
      collection.valid?
      expect(collection.slug).to eq('custom-slug')
    end
  end

  describe '#to_param' do
    it 'returns the slug instead of ID for routing' do
      collection = Collection.new(name: 'Mens wear')
      collection.valid?
      expect(collection.to_param).to eq('mens-wear')
    end
  end
end
