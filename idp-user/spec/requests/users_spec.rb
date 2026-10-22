require 'rails_helper'

RSpec.describe 'Users', type: :request do
  describe 'POST /api/v1/users' do
    let(:internal_api_key) { ENV.fetch('INTERNAL_API_KEY') }
    let(:headers) { { 'X-Internal-API-Key' => internal_api_key } }

    let(:valid_params) do
      {
        user: {
          email: 'test@example.com',
          password: 'password123',
          name: 'Test User'
        }
      }
    end

    let(:invalid_params) do
      {
        user: {
          email: '',
          password: 'short',
          name: ''
        }
      }
    end

    context '有効なパラメータの場合' do
      it 'ユーザーを作成する' do
        expect do
          post '/api/v1/users', params: valid_params, headers: headers
        end.to change(User, :count).by(1)
      end

      it '201 Created を返す' do
        post '/api/v1/users', params: valid_params, headers: headers
        expect(response).to have_http_status(:created)
      end

      it '作成されたユーザーの情報を返す（password_digest 除く）' do
        post '/api/v1/users', params: valid_params, headers: headers
        json = response.parsed_body
        expect(json).to include('email', 'name', 'id')
        expect(json).not_to include('password_digest')
      end

      it 'password_digest が bcrypt で保存される' do
        post '/api/v1/users', params: valid_params, headers: headers
        user = User.find_by(email: 'test@example.com')
        expect(user.password_digest).to start_with('$2a$') # bcrypt prefix
      end
    end

    context '無効なパラメータの場合' do
      it 'ユーザーを作成しない' do
        expect do
          post '/api/v1/users', params: invalid_params, headers: headers
        end.not_to change(User, :count)
      end

      it '422 Unprocessable Entity を返す' do
        post '/api/v1/users', params: invalid_params, headers: headers
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'エラーメッセージを返す' do
        post '/api/v1/users', params: invalid_params, headers: headers
        json = response.parsed_body
        expect(json['errors']).to be_present
      end
    end

    context '重複したメールアドレスの場合' do
      before { create(:user, email: 'test@example.com') }

      it 'ユーザーを作成しない' do
        expect do
          post '/api/v1/users', params: valid_params, headers: headers
        end.not_to change(User, :count)
      end

      it '422 Unprocessable Entity を返す' do
        post '/api/v1/users', params: valid_params, headers: headers
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context '内部APIキーが不正または未指定の場合' do
      it 'ヘッダー未指定なら 401 Unauthorized を返す' do
        expect do
          post '/api/v1/users', params: valid_params
        end.not_to change(User, :count)
        expect(response).to have_http_status(:unauthorized)
      end

      it '不正なキーなら 401 Unauthorized を返す' do
        expect do
          post '/api/v1/users', params: valid_params, headers: { 'X-Internal-API-Key' => 'wrong-key' }
        end.not_to change(User, :count)
        expect(response).to have_http_status(:unauthorized)
      end

      it 'エラーメッセージにパスワード等の入力値を含めない' do
        post '/api/v1/users', params: valid_params
        expect(response.body).not_to include('password123')
      end
    end

    context '境界値・形式・空白のみの入力の場合' do
      it '7文字の password ではユーザーを作成せず 422 を返す' do
        expect do
          post '/api/v1/users',
               params: { user: { email: 'edge@example.com', password: 'a' * 7, name: 'Edge' } },
               headers: headers
        end.not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it '101文字の name ではユーザーを作成せず 422 を返す' do
        params = { user: { email: 'edge@example.com', password: 'password123', name: 'あ' * 101 } }
        expect do
          post '/api/v1/users', params: params, headers: headers
        end.not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it '不正な形式の email ではユーザーを作成せず 422 を返す' do
        expect do
          post '/api/v1/users',
               params: { user: { email: 'invalid-email', password: 'password123', name: 'Edge' } },
               headers: headers
        end.not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it '空白のみの name ではユーザーを作成せず 422 を返す' do
        expect do
          post '/api/v1/users',
               params: { user: { email: 'edge@example.com', password: 'password123', name: '   ' } },
               headers: headers
        end.not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'GET /api/v1/users/:id' do
    let!(:user) { create(:user, email: 'test@example.com', password: 'password123', name: 'Test User') }
    let(:internal_api_key) { ENV.fetch('INTERNAL_API_KEY') }
    let(:headers) { { 'X-Internal-API-Key' => internal_api_key } }

    context '有効なAPIキーの場合' do
      it '200 OK を返す' do
        get "/api/v1/users/#{user.id}", headers: headers
        expect(response).to have_http_status(:ok)
      end

      it 'ユーザー情報を返す（password_digest 除く）' do
        get "/api/v1/users/#{user.id}", headers: headers
        json = response.parsed_body
        expect(json).to include('id', 'email', 'name')
        expect(json).not_to include('password_digest')
      end
    end

    context 'APIキーがない場合' do
      it '401 Unauthorized を返す' do
        get "/api/v1/users/#{user.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'APIキーが不正の場合' do
      it '401 Unauthorized を返す' do
        get "/api/v1/users/#{user.id}", headers: { 'X-Internal-API-Key' => 'wrong-key' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context '存在しないユーザーの場合' do
      it '404 Not Found を返す' do
        get '/api/v1/users/00000000-0000-0000-0000-000000000000', headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
