require 'bcrypt'

# テスト用ユーザー（development/test のみ）
if Rails.env.development? || Rails.env.test?
  user = User.find_or_initialize_by(email: 'test@example.com')
  user.assign_attributes(
    password_hash: BCrypt::Password.create('password123'),
    name: 'Test User'
  )
  user.save!
end
