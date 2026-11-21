require 'bcrypt'

# デモ RP 用クライアント（development のみ）。SSO を確かめるため、別ポートで動く 2 つの RP を登録する
if Rails.env.development?
  [
    { client_id: '550e8400-e29b-41d4-a716-446655440000', secret: 'demo_secret', name: 'Demo RP', port: 5174 },
    { client_id: '550e8400-e29b-41d4-a716-446655440002', secret: 'demo_secret_2', name: 'Demo RP 2', port: 5175 }
  ].each do |attrs|
    client = Client.find_or_initialize_by(client_id: attrs[:client_id])
    client.assign_attributes(
      client_secret_hash: BCrypt::Password.create(attrs[:secret]),
      name: attrs[:name],
      redirect_uris: "http://localhost:#{attrs[:port]}/callback\nhttp://localhost:#{attrs[:port]}/",
      allowed_scopes: 'openid profile email'
    )
    client.save!
  end
end
