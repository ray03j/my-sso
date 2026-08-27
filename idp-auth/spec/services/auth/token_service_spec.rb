require 'rails_helper'

RSpec.describe Auth::TokenService do
  describe '.issue_access_token' do
    it 'JWT アクセストークンを発行する' do
      token = described_class.issue_access_token(
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        client_id: '550e8400-e29b-41d4-a716-446655440001'
      )
      expect(token).to be_present
      expect(AccessToken.count).to eq(1)
    end

    it '発行したJWTを検証できる' do
      token = described_class.issue_access_token(
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        client_id: '550e8400-e29b-41d4-a716-446655440001'
      )
      payload = described_class.verify_access_token(token)
      expect(payload['sub']).to eq('550e8400-e29b-41d4-a716-446655440000')
      expect(payload['client_id']).to eq('550e8400-e29b-41d4-a716-446655440001')
      expect(payload['exp']).to be_present
    end
  end

  describe '.verify_access_token' do
    it '改竄されたJWTを拒否する' do
      token = described_class.issue_access_token(
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        client_id: '550e8400-e29b-41d4-a716-446655440001'
      )
      tampered = "#{token[0..-5]}XXXX"
      expect do
        described_class.verify_access_token(tampered)
      end.to raise_error(Auth::TokenService::InvalidTokenError)
    end
  end

  describe '.issue_refresh_token' do
    it 'リフレッシュトークンを発行する' do
      token = described_class.issue_refresh_token(
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        client_id: '550e8400-e29b-41d4-a716-446655440001'
      )
      expect(token).to be_present
      expect(RefreshToken.count).to eq(1)
    end
  end
end
