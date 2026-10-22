require 'rails_helper'

RSpec.describe 'Auth Verify', type: :request do
  let!(:user) { create(:user, email: 'test@example.com', password: 'password123') }
  let(:internal_api_key) { ENV.fetch('INTERNAL_API_KEY') }
  let(:headers) { { 'X-Internal-API-Key' => internal_api_key } }

  describe 'POST /api/v1/auth/verify' do
    context '正しい認証情報の場合' do
      it '200 OK を返す' do
        post '/api/v1/auth/verify', params: { email: 'test@example.com', password: 'password123' }, headers: headers
        expect(response).to have_http_status(:ok)
      end

      it 'ユーザー情報を返す（password_digest 除く）' do
        post '/api/v1/auth/verify', params: { email: 'test@example.com', password: 'password123' }, headers: headers
        json = response.parsed_body
        expect(json['user']).to include('id', 'email', 'name')
        expect(json['user']).not_to include('password_digest')
      end
    end

    context '誤ったパスワードの場合' do
      it '401 Unauthorized を返す' do
        post '/api/v1/auth/verify', params: { email: 'test@example.com', password: 'wrongpassword' }, headers: headers
        expect(response).to have_http_status(:unauthorized)
      end

      it 'code: INVALID_CREDENTIALS を返す' do
        post '/api/v1/auth/verify', params: { email: 'test@example.com', password: 'wrongpassword' }, headers: headers
        json = response.parsed_body
        expect(json['code']).to eq('INVALID_CREDENTIALS')
      end
    end

    context '存在しないメールの場合' do
      it '401 Unauthorized を返す' do
        params = { email: 'nonexistent@example.com', password: 'password123' }
        post '/api/v1/auth/verify', params: params, headers: headers
        expect(response).to have_http_status(:unauthorized)
      end

      it 'code: INVALID_CREDENTIALS を返す' do
        params = { email: 'nonexistent@example.com', password: 'password123' }
        post '/api/v1/auth/verify', params: params, headers: headers
        json = response.parsed_body
        expect(json['code']).to eq('INVALID_CREDENTIALS')
      end
    end

    context '内部APIキーが不正または未指定の場合' do
      it 'ヘッダー未指定なら 401 Unauthorized を返す' do
        post '/api/v1/auth/verify', params: { email: 'test@example.com', password: 'password123' }
        expect(response).to have_http_status(:unauthorized)
      end

      it '不正なキーなら 401 Unauthorized を返す' do
        post '/api/v1/auth/verify',
             params: { email: 'test@example.com', password: 'password123' },
             headers: { 'X-Internal-API-Key' => 'wrong-key' }
        expect(response).to have_http_status(:unauthorized)
      end

      it '正しいキーでも認証情報は検証しない' do
        post '/api/v1/auth/verify',
             params: { email: 'test@example.com', password: 'wrongpassword' },
             headers: headers
        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body['code']).to eq('INVALID_CREDENTIALS')
      end
    end
  end
end
