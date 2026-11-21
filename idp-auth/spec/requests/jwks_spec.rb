require 'rails_helper'

RSpec.describe 'JWKS', type: :request do
  describe 'GET /jwks.json' do
    let(:keys) { response.parsed_body['keys'] }

    it '認証なしで 200 OK を返すこと' do
      get '/jwks.json'
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/json')
    end

    it '署名検証用の RSA 公開鍵を返すこと' do
      get '/jwks.json'
      expect(keys.size).to eq(1)
      expect(keys.first).to include('kty' => 'RSA', 'use' => 'sig', 'alg' => 'RS256')
      expect(keys.first).to include('kid', 'n', 'e')
    end

    it '秘密鍵の成分（d / p / q / dp / dq / qi）を含まないこと' do
      get '/jwks.json'
      keys.each do |key|
        expect(key.keys).not_to include('d', 'p', 'q', 'dp', 'dq', 'qi')
      end
    end

    it 'Cache-Control に public と max-age を付けること' do
      get '/jwks.json'
      expect(response.headers['Cache-Control']).to include('public', 'max-age=3600')
    end

    it 'Discovery の jwks_uri のパスで取得できること' do
      get '/.well-known/openid-configuration'
      get URI.parse(response.parsed_body['jwks_uri']).path
      expect(response).to have_http_status(:ok)
    end

    it '発行した JWT を、ヘッダの kid に一致する公開鍵だけで検証できること' do
      token = Auth::TokenService.issue_id_token(
        user_id: '550e8400-e29b-41d4-a716-446655440000', client_id: '550e8400-e29b-41d4-a716-446655440001'
      )
      get '/jwks.json'

      jwks = JWT::JWK::Set.new(response.parsed_body)
      payload, header = JWT.decode(token, nil, true, algorithms: ['RS256'], jwks: jwks)
      expect(keys.pluck('kid')).to include(header['kid'])
      expect(payload['sub']).to eq('550e8400-e29b-41d4-a716-446655440000')
    end
  end
end
