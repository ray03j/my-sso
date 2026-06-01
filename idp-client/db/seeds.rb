require 'bcrypt'

# テスト用クライアント（デモ RP 用）
Client.create!(
  client_id: 'demo_client',
  client_secret_hash: BCrypt::Password.create('demo_secret'),
  name: 'Demo Relying Party',
  redirect_uris: "http://localhost:5174/callback\nhttp://localhost:5174/",
  allowed_scopes: "openid profile email"
)
