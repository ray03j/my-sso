require 'bcrypt'

# テスト用ユーザー（development/test のみ）
if Rails.env.development? || Rails.env.test?
  user = User.find_or_initialize_by(email: 'test@example.com')
  cost = Rails.env.test? ? BCrypt::Engine::MIN_COST : BCrypt::Engine::DEFAULT_COST
  user.assign_attributes(
    password_hash: BCrypt::Password.create('password123', cost: cost),
    name: 'Test User'
  )
  user.save!
end
