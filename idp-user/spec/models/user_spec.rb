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

  describe '文字数の境界値' do
    it 'name が1文字の場合、有効' do
      user = build(:user, name: 'あ')
      expect(user).to be_valid
    end

    it 'name が100文字の場合、有効' do
      user = build(:user, name: 'あ' * 100)
      expect(user).to be_valid
    end

    it 'name が101文字の場合、無効' do
      user = build(:user, name: 'あ' * 101)
      expect(user).not_to be_valid
      expect(user.errors[:name]).to be_present
    end

    it 'password が8文字の場合、有効' do
      user = build(:user, password: 'a' * 8)
      expect(user).to be_valid
    end

    it 'password が7文字の場合、無効' do
      user = build(:user, password: 'a' * 7)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it 'password が72文字の場合、有効' do
      user = build(:user, password: 'a' * 72)
      expect(user).to be_valid
    end

    it 'password が73文字の場合、無効' do
      user = build(:user, password: 'a' * 73)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it 'password が72バイトの多バイト文字列の場合、有効' do
      user = build(:user, password: 'あ' * 24)
      expect(user).to be_valid
    end

    it 'password が73バイトの多バイト文字列の場合、無効' do
      user = build(:user, password: "#{'あ' * 24}a")
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end
  end

  describe 'email の形式' do
    it '有効な形式の場合、有効' do
      user = build(:user, email: 'user.name+tag@example.co.jp')
      expect(user).to be_valid
    end

    it '不正な形式の場合、無効' do
      invalid_emails = [
        'plainaddress',
        'user@',
        '@example.com',
        'user@example',
        'user name@example.com'
      ]
      invalid_emails.each do |email|
        user = build(:user, email: email)
        expect(user).not_to be_valid, "#{email.inspect} は無効であるべき"
        expect(user.errors[:email]).to be_present
      end
    end
  end

  describe '空白のみの入力' do
    it 'name が空白のみの場合、無効' do
      user = build(:user, name: '   ')
      expect(user).not_to be_valid
      expect(user.errors[:name]).to be_present
    end

    it 'email が空白のみの場合、無効' do
      user = build(:user, email: '   ')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end

    it 'password が空白のみの場合、無効' do
      user = build(:user, password: ' ' * 8)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end
  end

  describe '前後の空白の正規化' do
    it 'email と name の前後の空白が除去される' do
      user = create(:user, email: '  spaced@example.com  ', name: '  Test User  ')
      expect(user.email).to eq('spaced@example.com')
      expect(user.name).to eq('Test User')
    end

    it '前後の空白を除去した結果が重複する email の場合、無効' do
      create(:user, email: 'dup@example.com')
      user = build(:user, email: '  dup@example.com  ')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end
  end
end
