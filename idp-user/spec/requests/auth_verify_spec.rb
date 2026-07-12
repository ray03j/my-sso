require 'rails_helper'

RSpec.describe 'Auth Verify', type: :request do
  let!(:user) { create(:user, email: 'test@example.com', password: 'password123') }

  describe 'POST /api/v1/auth/verify' do
    context '正しい認証情報の場合' do
      it '200 OK を返す' do
        post '/api/v1/auth/verify', params: { email: 'test@example.com', password: 'password123' }
        expect(response).to have_http_status(:ok)
      end

      it 'ユーザー情報を返す（password_digest 除く）' do
        post '/api/v1/auth/verify', params: { email: 'test@example.com', password: 'password123' }
        json = response.parsed_body
        expect(json['user']).to include('id', 'email', 'name')
        expect(json['user']).not_to include('password_digest')
      end
    end

    context '誤ったパスワードの場合' do
      it '401 Unauthorized を返す' do
        post '/api/v1/auth/verify', params: { email: 'test@example.com', password: 'wrongpassword' }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'code: INVALID_CREDENTIALS を返す' do
        post '/api/v1/auth/verify', params: { email: 'test@example.com', password: 'wrongpassword' }
        json = response.parsed_body
        expect(json['code']).to eq('INVALID_CREDENTIALS')
      end
    end

    context '存在しないメールの場合' do
      it '401 Unauthorized を返す' do
        post '/api/v1/auth/verify', params: { email: 'nonexistent@example.com', password: 'password123' }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'code: INVALID_CREDENTIALS を返す' do
        post '/api/v1/auth/verify', params: { email: 'nonexistent@example.com', password: 'password123' }
        json = response.parsed_body
        expect(json['code']).to eq('INVALID_CREDENTIALS')
      end
    end
  end
end
