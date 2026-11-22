require 'rails_helper'

RSpec.describe 'POST /revoke', type: :request do
  let(:user_id) { '550e8400-e29b-41d4-a716-446655440000' }
  let(:client_id) { '550e8400-e29b-41d4-a716-446655440001' }
  let(:client) { { 'client_id' => client_id } }
  let(:basic_header) do
    { 'Authorization' => "Basic #{Base64.strict_encode64("#{client_id}:correct_secret")}" }
  end
  let(:access_token) do
    Auth::TokenService.issue_access_token(user_id: user_id, client_id: client_id, scope: 'openid')
  end
  let(:refresh_token) { Auth::TokenService.issue_refresh_token(user_id: user_id, client_id: client_id) }

  before do
    allow(HTTParty).to receive(:post).and_return(double(success?: true, parsed_response: client))
  end

  context 'クライアント認証に成功した場合' do
    it 'access_token を失効させて 200 OK を返すこと' do
      post '/revoke', params: { token: access_token, token_type_hint: 'access_token' }, headers: basic_header
      expect(response).to have_http_status(:ok)
      expect(AccessToken.find_by(token: access_token)).to be_revoked
    end

    it '失効させた access_token では UserInfo を使えなくなること' do
      post '/revoke', params: { token: access_token }, headers: basic_header
      get '/userinfo', headers: { 'Authorization' => "Bearer #{access_token}" }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'refresh_token を失効させて 200 OK を返すこと' do
      post '/revoke', params: { token: refresh_token, token_type_hint: 'refresh_token' }, headers: basic_header
      expect(response).to have_http_status(:ok)
      expect(RefreshToken.find_by(token: refresh_token)).to be_revoked
    end

    it '失効させた refresh_token ではトークンを更新できなくなること' do
      post '/revoke', params: { token: refresh_token }, headers: basic_header
      post '/token', params: { grant_type: 'refresh_token', refresh_token: refresh_token }, headers: basic_header
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('invalid_grant')
    end

    it 'client_secret_post でもクライアント認証できること' do
      post '/revoke', params: { token: access_token, client_id: client_id, client_secret: 'correct_secret' }
      expect(response).to have_http_status(:ok)
      expect(AccessToken.find_by(token: access_token)).to be_revoked
    end

    it '存在しないトークンでも 200 OK を返すこと（RFC 7009 §2.2）' do
      post '/revoke', params: { token: 'unknown-token' }, headers: basic_header
      expect(response).to have_http_status(:ok)
    end

    it '他のクライアントのトークンは失効させず、200 OK を返すこと' do
      other = Auth::TokenService.issue_access_token(
        user_id: user_id, client_id: '550e8400-e29b-41d4-a716-446655440002', scope: 'openid'
      )
      post '/revoke', params: { token: other }, headers: basic_header
      expect(response).to have_http_status(:ok)
      expect(AccessToken.find_by(token: other)).not_to be_revoked
    end

    it 'token がなければ 400 と error=invalid_request を返すこと' do
      post '/revoke', headers: basic_header
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('invalid_request')
    end
  end

  context 'クライアント認証に失敗した場合' do
    before do
      allow(HTTParty).to receive(:post).and_return(double(success?: false))
    end

    it '401 と error=invalid_client、WWW-Authenticate: Basic を返し、失効させないこと' do
      post '/revoke', params: { token: access_token }, headers: basic_header
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body['error']).to eq('invalid_client')
      expect(response.headers['WWW-Authenticate']).to start_with('Basic')
      expect(AccessToken.find_by(token: access_token)).not_to be_revoked
    end
  end
end
