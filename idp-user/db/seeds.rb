require 'bcrypt'

# テスト用ユーザー
User.create!(
  email: 'test@example.com',
  password_hash: BCrypt::Password.create('password123'),
  name: 'Test User'
)
