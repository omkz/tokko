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

    it 'generates a unique slug with suffix when name is taken' do
      Collection.create!(name: 'Summer Sale')
      duplicate = Collection.create!(name: 'Summer Sale')
      expect(duplicate.slug).to start_with('summer-sale')
      expect(duplicate.slug).not_to eq('summer-sale')
    end
  end

  describe 'slug generation' do
    it 'parameterizes the name into a slug' do
      collection = Collection.create!(name: 'New & Exclusive Arrivals!')
      expect(collection.slug).to eq('new-exclusive-arrivals')
    end

    it 'does not overwrite a manually set slug' do
      collection = Collection.create!(name: 'Summer Sale')
      collection.update!(slug: 'custom-slug')
      expect(collection.reload.slug).to eq('custom-slug')
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
