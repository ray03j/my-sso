require 'rails_helper'

RSpec.describe 'GET /api/v1/authorization_request', type: :request do
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
      response_type: 'code', client_id: client['client_id'], redirect_uri: 'http://localhost:5174/callback',
      scope: 'openid profile', state: 'abc123',
      code_challenge: 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk', code_challenge_method: 'S256'
    }
  end

  before do
    allow(HTTParty).to receive(:get).and_return(double(success?: true, parsed_response: client))
  end

  context 'ログイン済みで、/authorize が同意のために中断した場合' do
    before do
      sign_in(user_id: '550e8400-e29b-41d4-a716-446655440000')
      get '/authorize', params: authorize_params
    end

    it 'RP 名と要求された scope を返すこと' do
      get '/api/v1/authorization_request'
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        'client_id' => client['client_id'], 'client_name' => 'Demo RP', 'scope' => 'openid profile'
      )
    end

    it 'RP が登録されていなければ 404 を返すこと' do
      allow(HTTParty).to receive(:get).and_return(double(success?: false))
      get '/api/v1/authorization_request'
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'ログイン済みでも、中断したリクエストがなければ 404 を返すこと' do
    sign_in(user_id: '550e8400-e29b-41d4-a716-446655440000')
    get '/api/v1/authorization_request'
    expect(response).to have_http_status(:not_found)
  end

  it '未ログインなら 401 を返すこと' do
    get '/api/v1/authorization_request'
    expect(response).to have_http_status(:unauthorized)
  end
end
