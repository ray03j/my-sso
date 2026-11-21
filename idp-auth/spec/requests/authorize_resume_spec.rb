require 'rails_helper'

RSpec.describe 'GET /authorize/continue', type: :request do
  let(:client) do
    {
      'client_id' => '550e8400-e29b-41d4-a716-446655440001',
      'name' => 'Demo RP',
      'redirect_uris' => ['http://localhost:5174/callback'],
      'allowed_scopes' => %w[openid profile email]
    }
  end
  let(:authorize_params) do
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
    allow(HTTParty).to receive(:get).and_return(double(success?: true, parsed_response: client))
  end

  context '/authorize が未ログインでパラメータを保存した場合' do
    before { get '/authorize', params: authorize_params }

    it '保存したパラメータで /authorize へリダイレクトすること' do
      get '/authorize/continue'
      expect(response).to have_http_status(:found)
      location = URI.parse(response.location)
      expect(location.path).to eq('/authorize')
      expect(Rack::Utils.parse_query(location.query)).to eq(authorize_params.stringify_keys)
    end

    it '保存したパラメータをセッションから消すこと' do
      get '/authorize/continue'
      expect(session[:authorize_params]).to be_nil
    end

    it 'ログイン・同意のあとに再開すると、認可コードを付けて RP に戻ること' do
      sign_in(user_id: user_id)
      Consent.create!(user_id: user_id, client_id: client['client_id'], scope: 'openid profile')

      get '/authorize/continue'
      follow_redirect!
      expect(response).to redirect_to(%r{\Ahttp://localhost:5174/callback\?code=.+&state=abc123\z})
    end

    it 'ログイン API でセッションを作り直しても、保存したパラメータで再開できること' do
      stub_request(:post, Auth::SessionService.idp_user_verify_url).to_return(
        status: 200,
        body: { user: { id: user_id, email: 'test@example.com', name: 'Test' } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      post '/api/v1/auth/session', params: { email: 'test@example.com', password: 'password123' }

      get '/authorize/continue'
      expect(URI.parse(response.location).path).to eq('/authorize')
    end

    it 'ログインしたが未同意なら、もう一度パラメータを保存して同意画面へ送ること' do
      sign_in(user_id: user_id)

      get '/authorize/continue'
      follow_redirect!
      expect(response).to redirect_to("#{AuthorizeController::FRONTEND_URL}/consent")
      expect(session[:authorize_params]).to include(authorize_params.stringify_keys)
    end
  end

  it '保存したパラメータがなければ 400 を返すこと' do
    get '/authorize/continue'
    expect(response).to have_http_status(:bad_request)
  end
end
