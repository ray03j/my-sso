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
  let(:login_url) { "#{AuthorizeController::FRONTEND_URL}/login" }
  let(:consent_url) { "#{AuthorizeController::FRONTEND_URL}/consent" }

  before do
    allow(HTTParty).to receive(:get).and_return(
      double(success?: true, parsed_response: client)
    )
  end

  context '未ログインの場合' do
    it 'ログイン画面へリダイレクトする' do
      get '/authorize', params: valid_params
      expect(response).to redirect_to(login_url)
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
      expect(response).to redirect_to(consent_url)
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
        get '/authorize', params: valid_params.merge(nonce: 'n-0S6_WzA2Mj')
      end.to change(AuthorizationCode, :count).by(1)
      expect(AuthorizationCode.last.nonce).to eq('n-0S6_WzA2Mj')
    end

    it 'スコープの空白違いの再要求では同意済みと判定して認可コードを発行する' do
      get '/authorize', params: valid_params.merge(scope: '  openid   profile  ')
      expect(response).to redirect_to(%r{http://localhost:5174/callback\?code=.+&state=abc123})
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
      expect(response).to redirect_to(consent_url)
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
      expect(response).to redirect_to(consent_url)
    end

    it '認可コードを発行しない' do
      expect do
        get '/authorize', params: valid_params.merge(scope: 'openid email')
      end.not_to change(AuthorizationCode, :count)
    end
  end

  describe 'POST /authorize' do
    context '未ログインの場合' do
      it 'ログイン画面へリダイレクトする' do
        post '/authorize', params: valid_params
        expect(response).to redirect_to(login_url)
      end

      it 'CSRF トークンがなくても、フォームで送られたパラメータを次のリクエストまでセッションに保持する', :forgery_protection do
        post '/authorize', params: valid_params
        get '/.well-known/openid-configuration'
        expect(session[:authorize_params]).to include(valid_params.stringify_keys)
      end
    end

    context 'ログイン済み・同意済みの場合' do
      before do
        sign_in(user_id: user_id)
        Consent.create!(user_id: user_id, client_id: client['client_id'], scope: 'openid profile')
      end

      it '認可コードを付与して redirect_uri へリダイレクトする' do
        post '/authorize', params: valid_params
        expect(response).to redirect_to(%r{http://localhost:5174/callback\?code=.+&state=abc123})
      end

      it 'フォームで送られた nonce を認可コードに保存する' do
        post '/authorize', params: valid_params.merge(nonce: 'n-0S6_WzA2Mj')
        expect(AuthorizationCode.last.nonce).to eq('n-0S6_WzA2Mj')
      end
    end

    context '必須パラメータが欠落している場合' do
      it 'error=invalid_request を返す' do
        post '/authorize', params: valid_params.except(:state)
        expect(response).to redirect_to('http://localhost:5174/callback?error=invalid_request')
      end
    end

    context '無効な client_id の場合' do
      before do
        allow(HTTParty).to receive(:get).and_return(double(success?: false, parsed_response: {}))
      end

      it '400 Bad Request を返す' do
        post '/authorize', params: valid_params
        expect(response).to have_http_status(:bad_request)
        expect(response.body).to eq('invalid_client')
      end
    end
  end

  describe 'prompt / max_age（OIDC Core §3.1.2.1）' do
    let(:callback) { 'http://localhost:5174/callback' }

    def record_consent
      Consent.create!(user_id: user_id, client_id: client['client_id'], scope: 'openid profile')
    end

    context 'prompt=none の場合' do
      it '未ログインなら画面を出さず error=login_required を返す' do
        get '/authorize', params: valid_params.merge(prompt: 'none')
        expect(response).to redirect_to("#{callback}?error=login_required&state=abc123")
      end

      it 'ログイン済み・未同意なら画面を出さず error=consent_required を返す' do
        sign_in(user_id: user_id)
        get '/authorize', params: valid_params.merge(prompt: 'none')
        expect(response).to redirect_to("#{callback}?error=consent_required&state=abc123")
      end

      it 'ログイン済み・同意済みなら認可コードを返す' do
        sign_in(user_id: user_id)
        record_consent
        get '/authorize', params: valid_params.merge(prompt: 'none')
        expect(response).to redirect_to(%r{\Ahttp://localhost:5174/callback\?code=.+&state=abc123\z})
      end

      it 'max_age を超えていれば error=login_required を返す' do
        sign_in(user_id: user_id, auth_time: 2.hours.ago.to_i)
        record_consent
        get '/authorize', params: valid_params.merge(prompt: 'none', max_age: 3600)
        expect(response).to redirect_to("#{callback}?error=login_required&state=abc123")
      end

      it '他の値と同時に指定されたら error=invalid_request を返す' do
        get '/authorize', params: valid_params.merge(prompt: 'none login')
        expect(response).to redirect_to("#{callback}?error=invalid_request&state=abc123")
      end
    end

    context 'prompt=login の場合' do
      before do
        sign_in(user_id: user_id)
        record_consent
      end

      it 'ログイン済み・同意済みでもログイン画面へリダイレクトする' do
        get '/authorize', params: valid_params.merge(prompt: 'login')
        expect(response).to redirect_to(login_url)
      end

      it 'ログイン後に再びログインを求めないよう、保存するパラメータから prompt を外す' do
        get '/authorize', params: valid_params.merge(prompt: 'login')
        expect(session[:authorize_params]).not_to have_key('prompt')
      end

      it 'login 以外の prompt の値は保存する' do
        get '/authorize', params: valid_params.merge(prompt: 'login consent')
        expect(session[:authorize_params]['prompt']).to eq('consent')
      end
    end

    context 'max_age を指定した場合' do
      before { record_consent }

      it '認証からの経過時間が max_age 以内なら認可コードを返す' do
        sign_in(user_id: user_id, auth_time: 10.minutes.ago.to_i)
        get '/authorize', params: valid_params.merge(max_age: 3600)
        expect(response).to redirect_to(%r{\Ahttp://localhost:5174/callback\?code=.+})
      end

      it '認証からの経過時間が max_age を超えていればログイン画面へリダイレクトする' do
        sign_in(user_id: user_id, auth_time: 2.hours.ago.to_i)
        get '/authorize', params: valid_params.merge(max_age: 3600)
        expect(response).to redirect_to(login_url)
      end

      it '認証時刻が分からないセッションならログイン画面へリダイレクトする' do
        sign_in(user_id: user_id, auth_time: nil)
        get '/authorize', params: valid_params.merge(max_age: 3600)
        expect(response).to redirect_to(login_url)
      end

      it '0 以上の整数でなければ error=invalid_request を返す' do
        sign_in(user_id: user_id)
        get '/authorize', params: valid_params.merge(max_age: '-1')
        expect(response).to redirect_to("#{callback}?error=invalid_request&state=abc123")
      end
    end

    context '認可コードを発行する場合' do
      it 'セッションの認証時刻を認可コードに保存する' do
        sign_in(user_id: user_id, auth_time: 1_700_000_000)
        record_consent
        get '/authorize', params: valid_params
        expect(AuthorizationCode.last.auth_time.to_i).to eq(1_700_000_000)
      end
    end
  end
end
