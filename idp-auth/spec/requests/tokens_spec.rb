require 'rails_helper'

RSpec.describe 'Tokens', type: :request do
  let(:client) do
    {
      'client_id' => '550e8400-e29b-41d4-a716-446655440001',
      'redirect_uris' => ['http://localhost:5174/callback'],
      'allowed_scopes' => %w[openid profile]
    }
  end

  let(:code_verifier) { 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk' }

  let!(:authorization_code) do
    AuthorizationCode.generate_for(
      user_id: '550e8400-e29b-41d4-a716-446655440000',
      client_id: client['client_id'],
      redirect_uri: 'http://localhost:5174/callback',
      scope: 'openid profile',
      code_challenge: Base64.urlsafe_encode64(
        Digest::SHA256.digest(code_verifier),
        padding: false
      ),
      code_challenge_method: 'S256'
    )
  end

  let(:valid_params) do
    {
      grant_type: 'authorization_code',
      code: authorization_code.code,
      redirect_uri: 'http://localhost:5174/callback',
      code_verifier: code_verifier,
      client_id: client['client_id'],
      client_secret: 'correct_secret'
    }
  end

  before do
    allow(HTTParty).to receive(:post).and_return(
      double(success?: true, parsed_response: client)
    )
  end

  context '有効なリクエストの場合' do
    it '200 OK を返す' do
      post '/token', params: valid_params
      expect(response).to have_http_status(:ok)
    end

    it 'access_token / id_token / refresh_token を返す' do
      post '/token', params: valid_params
      json = response.parsed_body
      expect(json).to include('access_token', 'id_token', 'refresh_token')
      expect(json['token_type']).to eq('Bearer')
      expect(json['expires_in']).to be_present
    end

    it '認可コードを使用済みにする' do
      post '/token', params: valid_params
      expect(authorization_code.reload.used?).to be true
    end
  end

  context '無効な client_secret の場合' do
    before do
      allow(HTTParty).to receive(:post).and_return(
        double(success?: false, parsed_response: { 'valid' => false })
      )
    end

    it '401 Unauthorized を返す' do
      post '/token', params: valid_params
      expect(response).to have_http_status(:unauthorized)
    end

    it 'error=invalid_client を返す' do
      post '/token', params: valid_params
      expect(response.parsed_body['error']).to eq('invalid_client')
    end
  end

  context 'PKCE が一致しない場合' do
    it '400 Bad Request を返す' do
      post '/token', params: valid_params.merge(code_verifier: 'wrong_verifier')
      expect(response).to have_http_status(:bad_request)
    end
  end

  context '既に使用済みの認可コードの場合' do
    before do
      authorization_code.update!(used: true)
    end

    it '400 Bad Request を返す' do
      post '/token', params: valid_params
      expect(response).to have_http_status(:bad_request)
    end
  end

  context 'redirect_uri が一致しない場合' do
    it '400 Bad Request を返す' do
      post '/token', params: valid_params.merge(redirect_uri: 'http://evil.example/callback')
      expect(response).to have_http_status(:bad_request)
    end
  end

  context 'grant_type が異なる場合' do
    it '400 Bad Request を返す' do
      post '/token', params: valid_params.merge(grant_type: 'password')
      expect(response).to have_http_status(:bad_request)
    end
  end
end
