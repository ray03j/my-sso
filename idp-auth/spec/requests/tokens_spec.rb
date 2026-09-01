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

    it '認可コードを使用済みにしない' do
      post '/token', params: valid_params.merge(code_verifier: 'wrong_verifier')
      expect(authorization_code.reload.used?).to be false
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

  context 'grant_type=refresh_token の場合' do
    let!(:refresh_token_record) do
      RefreshToken.generate_for(
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        client_id: client['client_id'],
        scope: 'openid profile'
      )
    end

    let(:refresh_params) do
      {
        grant_type: 'refresh_token',
        refresh_token: refresh_token_record.token,
        client_id: client['client_id'],
        client_secret: 'correct_secret'
      }
    end

    it '200 OK と新しい access_token / refresh_token を返す' do
      post '/token', params: refresh_params
      json = response.parsed_body

      expect(response).to have_http_status(:ok)
      expect(json).to include('access_token', 'refresh_token', 'token_type', 'expires_in', 'scope')
      expect(json['token_type']).to eq('Bearer')
    end

    it 'id_token は返さない' do
      post '/token', params: refresh_params
      expect(response.parsed_body).not_to include('id_token')
    end

    it '旧 refresh_token を失効させ、異なる新しい refresh_token を返す（回転）' do
      post '/token', params: refresh_params
      json = response.parsed_body

      expect(refresh_token_record.reload).to be_revoked
      expect(json['refresh_token']).not_to eq(refresh_token_record.token)
    end

    it 'scope を渡さなければ元の付与スコープを維持する' do
      post '/token', params: refresh_params
      expect(response.parsed_body['scope']).to eq('openid profile')
    end

    it 'scope を狭めて更新できる' do
      post '/token', params: refresh_params.merge(scope: 'openid')
      expect(response.parsed_body['scope']).to eq('openid')
    end

    it 'scope が元の付与を超える場合は error=invalid_scope を返す' do
      post '/token', params: refresh_params.merge(scope: 'openid email')

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('invalid_scope')
    end

    it '存在しない refresh_token の場合は error=invalid_grant を返す' do
      post '/token', params: refresh_params.merge(refresh_token: 'unknown')

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('invalid_grant')
    end

    it 'client_id が一致しない場合は error=invalid_grant を返す' do
      post '/token', params: refresh_params.merge(client_id: '550e8400-e29b-41d4-a716-446655440099')

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('invalid_grant')
    end

    it '期限切れの refresh_token の場合は error=invalid_grant を返す' do
      refresh_token_record.update!(expires_at: 1.second.ago)
      post '/token', params: refresh_params

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('invalid_grant')
    end

    it '回転後の旧トークン再提示は再利用検知で拒否され、新トークンも失効する' do
      post '/token', params: refresh_params
      new_token = response.parsed_body['refresh_token']

      post '/token', params: refresh_params

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('invalid_grant')
      expect(RefreshToken.find_by(token: new_token)).to be_revoked
    end

    it '無効な client_secret の場合は error=invalid_client（401）を返す' do
      allow(HTTParty).to receive(:post).and_return(
        double(success?: false, parsed_response: { 'valid' => false })
      )
      post '/token', params: refresh_params

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body['error']).to eq('invalid_client')
    end

    it 'refresh_token が欠落している場合は error=invalid_request を返す' do
      post '/token', params: refresh_params.except(:refresh_token)

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('invalid_request')
    end
  end
end
