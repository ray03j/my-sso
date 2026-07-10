require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'ユーザーの作成' do
    it 'email, password, name が必須' do
      user = User.new
      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
      expect(user.errors[:password]).to be_present
      expect(user.errors[:name]).to be_present
    end

    it 'email は一意である' do
      create(:user, email: 'test@example.com')
      user = build(:user, email: 'test@example.com')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end

    it 'password が present の場合、保存時にハッシュ化される' do
      user = User.new(email: 'test@example.com', password: 'password123', name: 'Test')
      user.save!
      expect(user.password_digest).to start_with('$2a$')
      expect(user.password_digest).not_to eq('password123')
    end
  end
end
