require 'rails_helper'

RSpec.describe 'Authorize', type: :request do
  let(:client) do
    {
      'client_id' => '550e8400-e29b-41d4-a716-446655440001',
      'redirect_uris' => ['http://localhost:5174/callback'],
      'allowed_scopes' => %w[openid profile email]
    }
  end

  let(:valid_params) do
    {
      response_type: 'code',
      client_id: client['client_id'],
      redirect_uri: 'http://localhost:5174/callback',
      scope: 'openid profile',
      state: 'abc123',
      code_challenge: 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk',
      code_challenge_method: 'S256'
    }
  end

  let(:user_id) { '550e8400-e29b-41d4-a716-446655440000' }

  before do
    allow(HTTParty).to receive(:get).and_return(
      double(success?: true, parsed_response: client)
    )
  end

  context '未ログインの場合' do
    it 'ログイン画面へリダイレクトする' do
      get '/authorize', params: valid_params
      expect(response).to redirect_to('/login')
    end

    it 'authorize パラメータをセッションに保持する' do
      get '/authorize', params: valid_params
      expect(session[:authorize_params]).to include(valid_params.stringify_keys)
    end
  end

  context 'ログイン済み・未同意の場合' do
    before do
      sign_in(user_id: user_id)
    end

    it '同意画面へリダイレクトする' do
      get '/authorize', params: valid_params
      expect(response).to redirect_to('/consent')
    end
  end

  context 'ログイン済み・同意済みの場合' do
    before do
      sign_in(user_id: user_id)
      Consent.create!(
        user_id: user_id,
        client_id: client['client_id'],
        scope: 'openid profile'
      )
    end

    it '認可コードを付与して redirect_uri へリダイレクトする' do
      get '/authorize', params: valid_params
      expect(response).to redirect_to(%r{http://localhost:5174/callback\?code=.+&state=abc123})
    end

    it '認可コードを発行する' do
      expect do
        get '/authorize', params: valid_params
      end.to change(AuthorizationCode, :count).by(1)
    end
  end

  context '無効な client_id の場合' do
    before do
      allow(HTTParty).to receive(:get).and_return(
        double(success?: false, parsed_response: {})
      )
    end

    it '400 Bad Request を返す' do
      get '/authorize', params: valid_params
      expect(response).to have_http_status(:bad_request)
      expect(response.body).to eq('invalid_client')
    end
  end

  context '許可されていない redirect_uri の場合' do
    before do
      sign_in(user_id: user_id)
    end

    it '400 Bad Request を返す' do
      get '/authorize', params: valid_params.merge(redirect_uri: 'http://evil.example/callback')
      expect(response).to have_http_status(:bad_request)
      expect(response.body).to eq('invalid_client')
    end
  end

  context '必須パラメータが欠落している場合' do
    it 'error=invalid_request を返す' do
      get '/authorize', params: valid_params.except(:state)
      expect(response).to redirect_to('http://localhost:5174/callback?error=invalid_request')
    end
  end

  context '必須パラメータが空文字の場合' do
    it 'error=invalid_request を返す' do
      get '/authorize', params: valid_params.merge(state: '')
      expect(response).to redirect_to('http://localhost:5174/callback?error=invalid_request')
    end
  end

  context '同意を拒否した後に再度 authorize を実行した場合' do
    before do
      sign_in(user_id: user_id)
      post '/api/v1/consent', params: { client_id: client['client_id'], scope: 'openid profile', approved: false }
    end

    it '再び同意画面へリダイレクトする' do
      get '/authorize', params: valid_params
      expect(response).to redirect_to('/consent')
    end

    it '認可コードを発行しない' do
      expect do
        get '/authorize', params: valid_params
      end.not_to change(AuthorizationCode, :count)
    end
  end

  context '同意済みだが要求スコープが同意内容と異なる場合' do
    before do
      sign_in(user_id: user_id)
      Consent.create!(
        user_id: user_id,
        client_id: client['client_id'],
        scope: 'openid profile'
      )
    end

    it '再び同意画面へリダイレクトする' do
      get '/authorize', params: valid_params.merge(scope: 'openid email')
      expect(response).to redirect_to('/consent')
    end

    it '認可コードを発行しない' do
      expect do
        get '/authorize', params: valid_params.merge(scope: 'openid email')
      end.not_to change(AuthorizationCode, :count)
    end
  end
end
