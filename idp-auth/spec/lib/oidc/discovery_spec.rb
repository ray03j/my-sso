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

    it 'OIDC Discovery 1.0 §3 の必須フィールドをすべて含む' do
      required = %i[
        issuer authorization_endpoint token_endpoint jwks_uri
        response_types_supported subject_types_supported id_token_signing_alg_values_supported
      ]
      metadata = described_class.metadata

      expect(required.select { |key| metadata[key].blank? }).to be_empty
    end

    it 'subject_types_supported は public のみ' do
      expect(described_class.metadata[:subject_types_supported]).to eq(['public'])
    end
  end
end
