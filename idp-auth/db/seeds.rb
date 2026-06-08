# 認可関連テーブルは運用データが主体のため、
# 本番では seeds.rb は使用しない。
# 開発・テスト環境用の最小データのみ記載。
#
# AuthorizationCode.create!(
#   code: 'test_code_12345',
#   user_id: '550e8400-e29b-41d4-a716-446655440000',
#   client_id: '550e8400-e29b-41d4-a716-446655440000',
#   redirect_uri: 'http://localhost:5174/callback',
#   scope: 'openid profile',
#   expires_at: 10.minutes.from_now
# )
