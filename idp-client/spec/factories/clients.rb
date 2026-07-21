FactoryBot.define do
  factory :client do
    sequence(:client_id) { SecureRandom.uuid }
    name { 'Test Relying Party' }
    redirect_uris { ['http://localhost:5174/callback'] }
    allowed_scopes { %w[openid profile] }
    client_secret { 'test_client_secret' }
  end
end
