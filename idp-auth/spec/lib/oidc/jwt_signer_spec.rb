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
  end
end
