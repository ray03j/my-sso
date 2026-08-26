require 'rails_helper'

RSpec.describe 'Users', type: :request do
  describe 'POST /api/v1/users' do
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
          post '/api/v1/users', params: valid_params
        end.to change(User, :count).by(1)
      end

      it '201 Created を返す' do
        post '/api/v1/users', params: valid_params
        expect(response).to have_http_status(:created)
      end

      it '作成されたユーザーの情報を返す（password_digest 除く）' do
        post '/api/v1/users', params: valid_params
        json = response.parsed_body
        expect(json).to include('email', 'name', 'id')
        expect(json).not_to include('password_digest')
      end

      it 'password_digest が bcrypt で保存される' do
        post '/api/v1/users', params: valid_params
        user = User.find_by(email: 'test@example.com')
        expect(user.password_digest).to start_with('$2a$') # bcrypt prefix
      end
    end

    context '無効なパラメータの場合' do
      it 'ユーザーを作成しない' do
        expect do
          post '/api/v1/users', params: invalid_params
        end.not_to change(User, :count)
      end

      it '422 Unprocessable Entity を返す' do
        post '/api/v1/users', params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'エラーメッセージを返す' do
        post '/api/v1/users', params: invalid_params
        json = response.parsed_body
        expect(json['errors']).to be_present
      end
    end

    context '重複したメールアドレスの場合' do
      before { create(:user, email: 'test@example.com') }

      it 'ユーザーを作成しない' do
        expect do
          post '/api/v1/users', params: valid_params
        end.not_to change(User, :count)
      end

      it '422 Unprocessable Entity を返す' do
        post '/api/v1/users', params: valid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET /api/v1/users/:id' do
    let!(:user) { create(:user, email: 'test@example.com', password: 'password123', name: 'Test User') }

    context '存在するユーザーの場合' do
      it '200 OK を返す' do
        get "/api/v1/users/#{user.id}"
        expect(response).to have_http_status(:ok)
      end

      it 'ユーザー情報を返す（password_digest 除く）' do
        get "/api/v1/users/#{user.id}"
        json = response.parsed_body
        expect(json).to include('id', 'email', 'name')
        expect(json).not_to include('password_digest')
      end
    end

    context '存在しないユーザーの場合' do
      it '404 Not Found を返す' do
        get '/api/v1/users/00000000-0000-0000-0000-000000000000'
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
