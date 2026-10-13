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

    it 'id_token が iss / sub / aud / exp / iat / at_hash クレームを持つ' do
      post '/token', params: valid_params
      payload, = Oidc::JwtSigner.verify(response.parsed_body['id_token'])
      expect(payload['iss']).to eq(Oidc::Discovery::ISSUER)
      expect(payload['sub']).to eq('550e8400-e29b-41d4-a716-446655440000')
      expect(payload['aud']).to eq(client['client_id'])
      expect(payload['exp']).to be > Time.current.to_i
      expect(payload['iat']).to be_present
      expect(payload['at_hash']).to be_present
    end

    it 'nonce を渡すと id_token の nonce クレームに含まれる' do
      post '/token', params: valid_params.merge(nonce: 'test-nonce')
      payload, = Oidc::JwtSigner.verify(response.parsed_body['id_token'])
      expect(payload['nonce']).to eq('test-nonce')
    end

    it 'at_hash が access_token の SHA-256 ハッシュ左半分と一致する' do
      post '/token', params: valid_params
      json = response.parsed_body
      expected = Base64.urlsafe_encode64(
        Digest::SHA256.digest(json['access_token'])[0, 16],
        padding: false
      )
      payload, = Oidc::JwtSigner.verify(json['id_token'])
      expect(payload['at_hash']).to eq(expected)
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

    it 'error=invalid_grant を返す' do
      post '/token', params: valid_params.merge(code_verifier: 'wrong_verifier')
      expect(response.parsed_body['error']).to eq('invalid_grant')
    end

    it '認可コードを使用済みにしない' do
      post '/token', params: valid_params.merge(code_verifier: 'wrong_verifier')
      expect(authorization_code.reload.used?).to be false
    end

    it 'code_verifier が空文字なら error=invalid_grant を返す' do
      post '/token', params: valid_params.merge(code_verifier: '')
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('invalid_grant')
    end
  end

  context '認可コードの不整合の場合' do
    it '他のクライアントの認可コードなら error=invalid_grant を返す' do
      other_code = AuthorizationCode.generate_for(
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        client_id: '550e8400-e29b-41d4-a716-446655440099',
        redirect_uri: 'http://localhost:5174/callback',
        code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false),
        code_challenge_method: 'S256'
      )
      post '/token', params: valid_params.merge(code: other_code.code)
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('invalid_grant')
    end

    it '存在しない認可コードなら error=invalid_grant を返す' do
      post '/token', params: valid_params.merge(code: 'non-existent-code')
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('invalid_grant')
    end

    it '期限切れの認可コードなら error=invalid_grant を返す' do
      authorization_code.update!(expires_at: 1.second.ago)
      post '/token', params: valid_params
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('invalid_grant')
    end
  end

  context '必須パラメータが欠落している場合' do
    it 'code_verifier が欠落すれば error=invalid_request を返す' do
      post '/token', params: valid_params.except(:code_verifier)
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('invalid_request')
    end

    it 'grant_type が欠落すれば error=invalid_request を返す' do
      post '/token', params: valid_params.except(:grant_type)
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('invalid_request')
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

    it 'error=invalid_grant を返す' do
      post '/token', params: valid_params
      expect(response.parsed_body['error']).to eq('invalid_grant')
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
