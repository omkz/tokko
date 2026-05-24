require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'role enum' do
    it 'defaults to customer' do
      user = User.new
      expect(user.role).to eq('customer')
    end
  end

  describe 'email normalization' do
    it 'strips whitespace and downcases the email address' do
      user = User.new(email_address: '  Test@EXample.com  ', password: 'password', password_confirmation: 'password')
      user.save! # This should trigger normalization if validations pass (assuming no other validations block it)
      expect(user.email_address).to eq('test@example.com')
    end
  end
end
