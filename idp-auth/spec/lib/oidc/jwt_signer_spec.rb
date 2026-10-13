require 'rails_helper'

RSpec.describe Oidc::JwtSigner do
  let(:payload) { { sub: 1, exp: 1.hour.from_now.to_i } }

  describe '.sign' do
    it 'JWT文字列を返す' do
      token = described_class.sign(payload)
      expect(token).to be_present
      expect(token.split('.').length).to eq(3)
    end
  end

  describe '.verify' do
    it '署名済みJWTを検証する' do
      token = described_class.sign(payload)
      decoded, = described_class.verify(token)
      expect(decoded['sub']).to eq(1)
    end

    it '改竄されたJWTを拒否する' do
      token = described_class.sign(payload)
      tampered = "#{token[0..-5]}XXXX"
      expect do
        described_class.verify(tampered)
      end.to raise_error(JWT::VerificationError)
    end

    it '期限切れのJWTを拒否する' do
      expired = described_class.sign({ sub: 1, exp: 1.hour.ago.to_i })
      expect do
        described_class.verify(expired)
      end.to raise_error(JWT::ExpiredSignature)
    end

    it '異なるシークレットで署名されたJWTを拒否する' do
      forged = JWT.encode({ sub: 1, exp: 1.hour.from_now.to_i }, 'wrong-secret', 'HS256')
      expect do
        described_class.verify(forged)
      end.to raise_error(JWT::VerificationError)
    end

    it 'alg=none の署名なしJWTを拒否する' do
      unsigned = JWT.encode({ sub: 1, exp: 1.hour.from_now.to_i }, nil, 'none')
      expect do
        described_class.verify(unsigned)
      end.to raise_error(JWT::IncorrectAlgorithm)
    end
  end
end
