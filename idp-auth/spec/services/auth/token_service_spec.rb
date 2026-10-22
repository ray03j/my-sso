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

    it 'sub / client_id / scope / exp / iat / jti クレームを含む' do
      token = described_class.issue_access_token(
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        client_id: '550e8400-e29b-41d4-a716-446655440001',
        scope: 'openid email'
      )
      payload = described_class.verify_access_token(token)
      expect(payload['sub']).to eq('550e8400-e29b-41d4-a716-446655440000')
      expect(payload['client_id']).to eq('550e8400-e29b-41d4-a716-446655440001')
      expect(payload['scope']).to eq('openid email')
      expect(payload['iat']).to be_present
      expect(payload['jti']).to be_present
    end

    it '有効期限は 15 分後' do
      token = described_class.issue_access_token(
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        client_id: '550e8400-e29b-41d4-a716-446655440001'
      )
      payload = described_class.verify_access_token(token)
      expect(payload['exp']).to be_within(5).of(15.minutes.from_now.to_i)
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

    it '期限切れのJWTを拒否する' do
      expired = Oidc::JwtSigner.sign(
        { sub: '550e8400-e29b-41d4-a716-446655440000', client_id: 'c1', scope: 'openid', exp: 1.hour.ago.to_i }
      )
      expect do
        described_class.verify_access_token(expired)
      end.to raise_error(Auth::TokenService::InvalidTokenError)
    end

    it '異なるシークレットで署名されたJWTを拒否する' do
      forged = JWT.encode(
        { sub: '550e8400-e29b-41d4-a716-446655440000', client_id: 'c1', scope: 'openid',
          exp: 1.hour.from_now.to_i },
        'wrong-secret', 'HS256'
      )
      expect do
        described_class.verify_access_token(forged)
      end.to raise_error(Auth::TokenService::InvalidTokenError)
    end

    it 'alg=none の署名なしJWTを拒否する' do
      unsigned = JWT.encode(
        { sub: '550e8400-e29b-41d4-a716-446655440000', client_id: 'c1', scope: 'openid',
          exp: 1.hour.from_now.to_i },
        nil, 'none'
      )
      expect do
        described_class.verify_access_token(unsigned)
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
