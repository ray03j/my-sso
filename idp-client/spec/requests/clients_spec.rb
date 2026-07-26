require 'spec_helper'

RSpec.describe 'Clients', type: :request do
  let(:internal_api_key) { ENV.fetch('INTERNAL_API_KEY') }
  let(:headers) { { 'X-Internal-API-Key' => internal_api_key } }

  describe 'POST /api/v1/clients' do
    let(:valid_params) do
      {
        client: {
          name: 'Test RP',
          redirect_uris: ['http://localhost:5174/callback'],
          allowed_scopes: %w[openid profile]
        }
      }
    end

    let(:invalid_params) do
      {
        client: {
          name: '',
          redirect_uris: ['not-a-url'],
          allowed_scopes: %w[openid invalid_scope]
        }
      }
    end

    context '有効なパラメータの場合' do
      it 'クライアントを作成する' do
        expect do
          post '/api/v1/clients', params: valid_params, headers: headers
        end.to change(Client, :count).by(1)
      end

      it '201 Created を返す' do
        post '/api/v1/clients', params: valid_params, headers: headers
        expect(response).to have_http_status(:created)
      end

      it 'client_id と平文 client_secret を返す' do
        post '/api/v1/clients', params: valid_params, headers: headers
        json = response.parsed_body
        expect(json).to include('client_id', 'client_secret')
        expect(json['client_secret']).to be_present
      end

      it '返された平文 client_secret が保存されたハッシュで検証できる' do
        post '/api/v1/clients', params: valid_params, headers: headers
        json = response.parsed_body
        client = Client.order(:created_at).last
        expect(client.client_secret_valid?(json['client_secret'])).to be(true)
      end

      it 'レスポンスに client_secret_hash が含まれない' do
        post '/api/v1/clients', params: valid_params, headers: headers
        json = response.parsed_body
        expect(json).not_to include('client_secret_hash')
      end
    end

    context '無効なパラメータの場合' do
      it 'クライアントを作成しない' do
        expect do
          post '/api/v1/clients', params: invalid_params, headers: headers
        end.not_to change(Client, :count)
      end

      it '422 Unprocessable Content を返す' do
        post '/api/v1/clients', params: invalid_params, headers: headers
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'エラーメッセージを返す' do
        post '/api/v1/clients', params: invalid_params, headers: headers
        json = response.parsed_body
        expect(json['errors']).to be_present
      end
    end

    context '内部APIキーが不正または未指定の場合' do
      it '不正なキーでは 401 Unauthorized を返す' do
        post '/api/v1/clients',
             params: valid_params,
             headers: { 'X-Internal-API-Key' => 'wrong-key' }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'ヘッダー未指定でも 401 Unauthorized を返す' do
        post '/api/v1/clients', params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end

      it 'クライアントを作成しない' do
        expect do
          post '/api/v1/clients', params: valid_params
        end.not_to change(Client, :count)
      end
    end
  end

  describe 'GET /api/v1/clients' do
    let!(:client) { create(:client) }

    it '200 OK を返す' do
      get '/api/v1/clients', headers: headers
      expect(response).to have_http_status(:ok)
    end

    it '登録済みクライアントの一覧を返す' do
      get '/api/v1/clients', headers: headers
      json = response.parsed_body
      expect(json['clients'].length).to eq(1)
      expect(json['clients'].first['client_id']).to eq(client.client_id)
    end

    it '一覧に client_secret_hash が含まれない' do
      get '/api/v1/clients', headers: headers
      json = response.parsed_body
      expect(json['clients'].first).not_to include('client_secret_hash', 'client_secret')
    end

    it '内部 API キーが不正な場合は 401 を返す' do
      get '/api/v1/clients', headers: { 'X-Internal-API-Key' => 'wrong-key' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'ヘッダー未指定の場合は 401 を返す' do
      get '/api/v1/clients'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/clients/:client_id' do
    let!(:client) { create(:client) }

    it '200 OK を返す' do
      get "/api/v1/clients/#{client.client_id}", headers: headers
      expect(response).to have_http_status(:ok)
    end

    it 'クライアント詳細を返す' do
      get "/api/v1/clients/#{client.client_id}", headers: headers
      json = response.parsed_body
      expect(json['client_id']).to eq(client.client_id)
      expect(json['name']).to eq(client.name)
      expect(json['redirect_uris']).to eq(client.redirect_uris)
      expect(json['allowed_scopes']).to eq(client.allowed_scopes)
    end

    it '詳細に client_secret_hash が含まれない' do
      get "/api/v1/clients/#{client.client_id}", headers: headers
      json = response.parsed_body
      expect(json).not_to include('client_secret_hash', 'client_secret')
    end

    it '存在しない client_id の場合は 404 を返す' do
      get '/api/v1/clients/non-existent-client-id', headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it '内部 API キーが不正な場合は 401 を返す' do
      get "/api/v1/clients/#{client.client_id}",
          headers: { 'X-Internal-API-Key' => 'wrong-key' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'ヘッダー未指定の場合は 401 を返す' do
      get "/api/v1/clients/#{client.client_id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
