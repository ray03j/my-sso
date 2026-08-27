require 'rails_helper'

RSpec.describe 'Discovery', type: :request do
  describe 'GET /.well-known/openid-configuration' do
    it '200 OK を返す' do
      get '/.well-known/openid-configuration'

      expect(response).to have_http_status(:ok)
    end

    it 'issuer を返す' do
      get '/.well-known/openid-configuration'

      expect(response.parsed_body['issuer']).to be_present
    end

    it 'OIDC 標準エンドポイントを返す' do
      get '/.well-known/openid-configuration'

      expect(response.parsed_body).to include(
        'authorization_endpoint',
        'token_endpoint',
        'userinfo_endpoint',
        'jwks_uri'
      )
    end

    it '認可コードフローと PKCE をサポート宣言する' do
      get '/.well-known/openid-configuration'
      json = response.parsed_body

      expect(json['response_types_supported']).to include('code')
      expect(json['code_challenge_methods_supported']).to include('S256')
      expect(json['scopes_supported']).to include('openid')
    end
  end
end
