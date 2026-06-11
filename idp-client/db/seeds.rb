require 'bcrypt'

# テスト用クライアント（デモ RP 用、development/test のみ）
if Rails.env.development? || Rails.env.test?
  client = Client.find_or_initialize_by(client_id: '550e8400-e29b-41d4-a716-446655440000')
  cost = Rails.env.test? ? BCrypt::Engine::MIN_COST : BCrypt::Engine::DEFAULT_COST
  client.assign_attributes(
    client_secret_hash: BCrypt::Password.create('demo_secret', cost: cost),
    name: 'Demo Relying Party',
    redirect_uris: "http://localhost:5174/callback\nhttp://localhost:5174/",
    allowed_scopes: "openid profile email"
  )
  client.save!
end
