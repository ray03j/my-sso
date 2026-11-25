require 'rails_helper'

RSpec.describe Auth::TokenRevocationService do
  let(:user_id) { '550e8400-e29b-41d4-a716-446655440000' }
  let(:client_id) { '550e8400-e29b-41d4-a716-446655440001' }
  let(:other_client_id) { '550e8400-e29b-41d4-a716-446655440002' }
  let!(:access_token) { AccessToken.generate_for(user_id: user_id, client_id: client_id) }
  let!(:refresh_token) { RefreshToken.generate_for(user_id: user_id, client_id: client_id) }

  describe '.revoke' do
    it 'access_token を失効させること' do
      described_class.revoke(token: access_token.token, client_id: client_id)
      expect(access_token.reload).to be_revoked
    end

    it 'refresh_token を失効させること' do
      described_class.revoke(token: refresh_token.token, client_id: client_id)
      expect(refresh_token.reload).to be_revoked
    end

    it 'refresh_token を失効させると、同じユーザー・クライアントの access_token も失効させること' do
      described_class.revoke(token: refresh_token.token, client_id: client_id)
      expect(access_token.reload).to be_revoked
    end

    it '失効済みの refresh_token でも、失効時刻は変えずに残っている access_token を失効させること' do
      refresh_token.revoke!
      revoked_at = refresh_token.reload.revoked_at
      described_class.revoke(token: refresh_token.token, client_id: client_id)
      expect(refresh_token.reload.revoked_at).to eq(revoked_at)
      expect(access_token.reload).to be_revoked
    end

    it 'refresh_token を失効させても、他のクライアントの access_token は失効させないこと' do
      other = AccessToken.generate_for(user_id: user_id, client_id: other_client_id)
      described_class.revoke(token: refresh_token.token, client_id: client_id)
      expect(other.reload).not_to be_revoked
    end

    it 'token_type_hint が実際の種類と違っても失効させること' do
      described_class.revoke(token: refresh_token.token, client_id: client_id, token_type_hint: 'access_token')
      expect(refresh_token.reload).to be_revoked
    end

    it '他のクライアントのトークンは失効させないこと' do
      described_class.revoke(token: access_token.token, client_id: other_client_id)
      expect(access_token.reload).not_to be_revoked
    end

    it '存在しないトークンではエラーにしないこと' do
      expect { described_class.revoke(token: 'unknown', client_id: client_id) }.not_to raise_error
    end
  end
end
