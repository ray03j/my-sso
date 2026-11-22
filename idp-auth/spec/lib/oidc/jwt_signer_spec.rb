require 'rails_helper'

RSpec.describe Oidc::JwtSigner do
  let(:payload) { { sub: 1, exp: 1.hour.from_now.to_i } }
  let(:kid) { described_class.jwks.first[:kid] }
  let(:other_key) { OpenSSL::PKey::RSA.generate(2048) }

  describe '.sign' do
    it 'JWT文字列を返すこと' do
      token = described_class.sign(payload)
      expect(token).to be_present
      expect(token.split('.').length).to eq(3)
    end

    it 'ヘッダに alg=RS256 と公開鍵の JWK Thumbprint を kid として含めること' do
      _, header = JWT.decode(described_class.sign(payload), nil, false)
      expect(header).to include('alg' => 'RS256', 'kid' => kid)
      expect(kid).to eq(JWT::JWK::Thumbprint.new(described_class.jwks.first).to_s)
    end
  end

  describe '.verify' do
    it '署名済みJWTを検証できること' do
      token = described_class.sign(payload)
      decoded, = described_class.verify(token)
      expect(decoded['sub']).to eq(1)
    end

    it '改竄されたJWTを拒否すること' do
      token = described_class.sign(payload)
      tampered = "#{token[0..-5]}XXXX"
      expect do
        described_class.verify(tampered)
      end.to raise_error(JWT::VerificationError)
    end

    it '期限切れのJWTを拒否すること' do
      expired = described_class.sign({ sub: 1, exp: 1.hour.ago.to_i })
      expect do
        described_class.verify(expired)
      end.to raise_error(JWT::ExpiredSignature)
    end

    it 'verify_expiration: false なら期限切れでも署名を検証できること' do
      expired = described_class.sign({ sub: 1, exp: 1.hour.ago.to_i })
      decoded, = described_class.verify(expired, verify_expiration: false)
      expect(decoded['sub']).to eq(1)
    end

    it 'verify_expiration: false でも改竄されたJWTは拒否すること' do
      expired = described_class.sign({ sub: 1, exp: 1.hour.ago.to_i })
      header, _payload, signature = expired.split('.')
      tampered = [header, Base64.urlsafe_encode64({ sub: 2 }.to_json, padding: false), signature].join('.')
      expect do
        described_class.verify(tampered, verify_expiration: false)
      end.to raise_error(JWT::VerificationError)
    end

    it '同じ kid で別の秘密鍵により署名されたJWTを拒否すること' do
      forged = JWT.encode(payload, other_key, 'RS256', { kid: kid })
      expect do
        described_class.verify(forged)
      end.to raise_error(JWT::VerificationError)
    end

    it 'JWKS にない kid のJWTを拒否すること' do
      forged = JWT.encode(payload, other_key, 'RS256', { kid: 'unknown-kid' })
      expect do
        described_class.verify(forged)
      end.to raise_error(JWT::DecodeError, /unknown-kid/)
    end

    it 'kid のないJWTを拒否すること' do
      forged = JWT.encode(payload, other_key, 'RS256')
      expect do
        described_class.verify(forged)
      end.to raise_error(JWT::DecodeError)
    end

    it '公開鍵を共通鍵として HS256 で署名したJWTを拒否すること（アルゴリズム混同攻撃）' do
      public_pem = described_class.jwks.first.verify_key.to_pem
      forged = JWT.encode(payload, public_pem, 'HS256', { kid: kid })
      expect do
        described_class.verify(forged)
      end.to raise_error(JWT::IncorrectAlgorithm)
    end

    it 'alg=none の署名なしJWTを拒否すること' do
      unsigned = JWT.encode({ sub: 1, exp: 1.hour.from_now.to_i }, nil, 'none')
      expect do
        described_class.verify(unsigned)
      end.to raise_error(JWT::IncorrectAlgorithm)
    end
  end

  describe '署名鍵の読み込み' do
    def load_private_key(pem)
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('JWT_PRIVATE_KEY', '').and_return(pem)
      described_class.send(:private_key)
    end

    it '改行を \\n とエスケープした PEM も読み込めること' do
      pem = other_key.to_pem
      expect(load_private_key(pem.gsub("\n", '\n')).to_pem).to eq(pem)
    end

    it '本番で JWT_PRIVATE_KEY が未設定なら KeyError になること' do
      allow(Rails.env).to receive(:production?).and_return(true)
      expect { load_private_key('') }.to raise_error(KeyError, /JWT_PRIVATE_KEY/)
    end

    it '本番以外で未設定なら鍵を生成すること' do
      expect(load_private_key('')).to be_a(OpenSSL::PKey::RSA).and be_private
    end
  end

  describe '.jwks' do
    let(:exported) { described_class.jwks.export[:keys] }

    it '署名に使う公開鍵を 1 つ含むこと' do
      expect(exported.size).to eq(1)
      expect(exported.first).to include(kty: 'RSA', use: 'sig', alg: 'RS256', kid: kid, e: 'AQAB')
      expect(exported.first[:n]).to be_present
    end

    it '秘密鍵の成分を含まないこと' do
      expect(exported.first.keys).not_to include(:d, :p, :q, :dp, :dq, :qi)
    end
  end
end
