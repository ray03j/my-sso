require 'rails_helper'

RSpec.describe Oidc::Discovery do
  describe '.metadata' do
    it '必要なOIDC Discoveryメタデータを含む' do
      metadata = described_class.metadata
      expect(metadata[:issuer]).to be_present
      expect(metadata[:authorization_endpoint]).to be_present
      expect(metadata[:token_endpoint]).to be_present
      expect(metadata[:userinfo_endpoint]).to be_present
      expect(metadata[:jwks_uri]).to be_present
      expect(metadata[:scopes_supported]).to include('openid', 'profile', 'email')
      expect(metadata[:grant_types_supported]).to include('authorization_code', 'refresh_token')
    end
  end
end
