require 'rails_helper'

RSpec.describe Auth::TokenService do
  describe '.issue_access_token' do
    it 'JWT アクセストークンを発行すること' do
      token = described_class.issue_access_token(
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        client_id: '550e8400-e29b-41d4-a716-446655440001'
      )
      expect(token).to be_present
      expect(AccessToken.count).to eq(1)
    end

    it '発行したJWTを検証できること' do
      token = described_class.issue_access_token(
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        client_id: '550e8400-e29b-41d4-a716-446655440001'
      )
      payload = described_class.verify_access_token(token)
      expect(payload['sub']).to eq('550e8400-e29b-41d4-a716-446655440000')
      expect(payload['client_id']).to eq('550e8400-e29b-41d4-a716-446655440001')
      expect(payload['exp']).to be_present
    end

    it 'sub / client_id / scope / exp / iat / jti クレームを含むこと' do
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

    it '有効期限は 15 分後であること' do
      token = described_class.issue_access_token(
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        client_id: '550e8400-e29b-41d4-a716-446655440001'
      )
      payload = described_class.verify_access_token(token)
      expect(payload['exp']).to be_within(5).of(15.minutes.from_now.to_i)
    end
  end

  describe '.issue_id_token' do
    let(:user_id) { '550e8400-e29b-41d4-a716-446655440000' }
    let(:client_id) { '550e8400-e29b-41d4-a716-446655440001' }

    def decode(token)
      Oidc::JwtSigner.verify(token).first
    end

    it 'auth_time を UNIX 時刻で含める' do
      token = described_class.issue_id_token(
        user_id: user_id, client_id: client_id, auth_time: Time.zone.at(1_700_000_000)
      )
      expect(decode(token)['auth_time']).to eq(1_700_000_000)
    end

    it 'auth_time がなければクレームを含めない' do
      token = described_class.issue_id_token(user_id: user_id, client_id: client_id)
      expect(decode(token)).not_to have_key('auth_time')
    end
  end

  describe '.verify_access_token' do
    it '改竄されたJWTを拒否すること' do
      token = described_class.issue_access_token(
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        client_id: '550e8400-e29b-41d4-a716-446655440001'
      )
      tampered = "#{token[0..-5]}XXXX"
      expect do
        described_class.verify_access_token(tampered)
      end.to raise_error(Auth::TokenService::InvalidTokenError)
    end

    it '期限切れのJWTを拒否すること' do
      expired = Oidc::JwtSigner.sign(
        { sub: '550e8400-e29b-41d4-a716-446655440000', client_id: 'c1', scope: 'openid', exp: 1.hour.ago.to_i }
      )
      expect do
        described_class.verify_access_token(expired)
      end.to raise_error(Auth::TokenService::InvalidTokenError)
    end

    it '同じ kid で別の秘密鍵により署名されたJWTを拒否すること' do
      forged = JWT.encode(
        { sub: '550e8400-e29b-41d4-a716-446655440000', client_id: 'c1', scope: 'openid',
          exp: 1.hour.from_now.to_i },
        OpenSSL::PKey::RSA.generate(2048), 'RS256', { kid: Oidc::JwtSigner.jwks.first[:kid] }
      )
      expect do
        described_class.verify_access_token(forged)
      end.to raise_error(Auth::TokenService::InvalidTokenError)
    end

    it 'alg=none の署名なしJWTを拒否すること' do
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
    it 'リフレッシュトークンを発行すること' do
      token = described_class.issue_refresh_token(
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        client_id: '550e8400-e29b-41d4-a716-446655440001'
      )
      expect(token).to be_present
      expect(RefreshToken.count).to eq(1)
    end
  end
end
