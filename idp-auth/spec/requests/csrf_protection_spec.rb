require 'rails_helper'

RSpec.describe 'CSRF 対策', :forgery_protection, type: :request do
  let(:client_id) { '550e8400-e29b-41d4-a716-446655440001' }
  let(:credentials) { { email: 'test@example.com', password: 'password123' } }

  before do
    stub_request(:post, Auth::SessionService.idp_user_verify_url)
      .to_return(
        status: 200,
        body: { user: { id: '550e8400-e29b-41d4-a716-446655440000', email: 'test@example.com', name: 'Test' } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def fetch_csrf_token
    get '/api/v1/auth/csrf_token'
    response.parsed_body['csrf_token']
  end

  describe 'GET /api/v1/auth/csrf_token' do
    it 'CSRF トークンを返すこと' do
      expect(fetch_csrf_token).to be_present
    end

    it 'トークンを紐づけるセッション Cookie を発行すること' do
      fetch_csrf_token
      expect(response.headers['Set-Cookie']).to include('_idp_auth_session=')
    end
  end

  context 'CSRF トークンを付けてログインした場合' do
    before do
      token = fetch_csrf_token
      post '/api/v1/auth/session', params: credentials, headers: { 'X-CSRF-Token' => token }
    end

    it '200 OK を返すこと' do
      expect(response).to have_http_status(:ok)
    end

    it '次のリクエストでもログイン済みであること' do
      post '/api/v1/consent',
           params: { client_id: client_id, scope: 'openid', approved: true },
           headers: { 'X-CSRF-Token' => fetch_csrf_token }
      expect(response).to have_http_status(:ok)
    end
  end

  context 'CSRF トークンなしでログインした場合' do
    before do
      post '/api/v1/auth/session', params: credentials
    end

    it '422 と error=invalid_csrf_token を返すこと' do
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq('invalid_csrf_token')
    end

    it 'セッション Cookie を発行しないこと' do
      expect(response.headers['Set-Cookie']).to be_nil
    end
  end

  it 'CSRF トークンなしの同意は 422 を返すこと' do
    post '/api/v1/consent', params: { client_id: client_id, scope: 'openid', approved: true }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'CSRF トークンなしのログアウトは 422 を返すこと' do
    delete '/api/v1/auth/session'
    expect(response).to have_http_status(:unprocessable_content)
  end
end
