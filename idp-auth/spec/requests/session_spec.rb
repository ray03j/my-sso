require 'rails_helper'

RSpec.describe 'Session', type: :request do
  let(:user_response) do
    { user: { id: 1, email: 'test@example.com', name: 'Test' } }
  end

  describe 'POST /api/v1/auth/session' do
    context '正しい認証情報の場合' do
      before do
        stub_request(:post, Auth::SessionService.idp_user_verify_url)
          .to_return(status: 200, body: user_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it '200 OK を返す' do
        post '/api/v1/auth/session', params: { email: 'test@example.com', password: 'password123' }
        expect(response).to have_http_status(:ok)
      end

      it 'セッションにユーザーIDを保存する' do
        post '/api/v1/auth/session', params: { email: 'test@example.com', password: 'password123' }
        expect(session[:user_id]).to eq(1)
      end

      it 'ユーザー情報を返す' do
        post '/api/v1/auth/session', params: { email: 'test@example.com', password: 'password123' }
        json = response.parsed_body
        expect(json['user']).to include('id', 'email', 'name')
      end
    end

    context '誤った認証情報の場合' do
      before do
        stub_request(:post, Auth::SessionService.idp_user_verify_url)
          .to_return(
            status: 401,
            body: { code: 'INVALID_CREDENTIALS' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it '401 Unauthorized を返す' do
        post '/api/v1/auth/session', params: { email: 'test@example.com', password: 'wrongpassword' }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'セッションにユーザーIDを保存しない' do
        post '/api/v1/auth/session', params: { email: 'test@example.com', password: 'wrongpassword' }
        expect(session[:user_id]).to be_nil
      end
    end
  end

  describe 'DELETE /api/v1/auth/session' do
    it '204 No Content を返す' do
      delete '/api/v1/auth/session'
      expect(response).to have_http_status(:no_content)
    end
  end
end
