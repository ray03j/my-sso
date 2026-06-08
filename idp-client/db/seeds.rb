require 'bcrypt'

# テスト用クライアント（デモ RP 用）
Client.create!(
  client_id: '550e8400-e29b-41d4-a716-446655440000',
  client_secret_hash: BCrypt::Password.create('demo_secret'),
  name: 'Demo Relying Party',
  redirect_uris: "http://localhost:5174/callback\nhttp://localhost:5174/",
  allowed_scopes: "openid profile email"
)
