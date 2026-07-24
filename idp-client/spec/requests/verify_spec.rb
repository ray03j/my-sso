require 'spec_helper'

RSpec.describe 'Verify', type: :request do
  let(:internal_api_key) { ENV.fetch('INTERNAL_API_KEY') }
  let!(:client) { create(:client, client_secret: 'correct_secret') }

  describe 'POST /api/v1/clients/verify' do
    context '内部APIキーが正しい場合' do
      let(:headers) { { 'X-Internal-API-Key' => internal_api_key } }

      context '有効な client_id / client_secret の場合' do
        it '200 OK を返す' do
          post '/api/v1/clients/verify',
               params: { client_id: client.client_id, client_secret: 'correct_secret' },
               headers: headers
          expect(response).to have_http_status(:ok)
        end

        it 'valid: true とクライアント情報を返す' do
          post '/api/v1/clients/verify',
               params: { client_id: client.client_id, client_secret: 'correct_secret' },
               headers: headers
          json = response.parsed_body
          expect(json['valid']).to be true
          expect(json['client_id']).to eq(client.client_id)
          expect(json['redirect_uris']).to eq(client.redirect_uris)
          expect(json['allowed_scopes']).to eq(client.allowed_scopes)
        end

        it 'client_secret_hash を含めない' do
          post '/api/v1/clients/verify',
               params: { client_id: client.client_id, client_secret: 'correct_secret' },
               headers: headers
          json = response.parsed_body
          expect(json).not_to include('client_secret_hash')
        end
      end

      context 'redirect_uri が指定された場合' do
        it '登録済みの redirect_uri なら 200 OK を返す' do
          post '/api/v1/clients/verify',
               params: {
                 client_id: client.client_id,
                 client_secret: 'correct_secret',
                 redirect_uri: client.redirect_uris.first
               },
               headers: headers
          expect(response).to have_http_status(:ok)
        end

        it '未登録の redirect_uri なら 401 Unauthorized を返す' do
          post '/api/v1/clients/verify',
               params: {
                 client_id: client.client_id,
                 client_secret: 'correct_secret',
                 redirect_uri: 'http://evil.example/callback'
               },
               headers: headers
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context '無効な client_secret の場合' do
        it '401 Unauthorized を返す' do
          post '/api/v1/clients/verify',
               params: { client_id: client.client_id, client_secret: 'wrong_secret' },
               headers: headers
          expect(response).to have_http_status(:unauthorized)
        end

        it 'valid: false を返す' do
          post '/api/v1/clients/verify',
               params: { client_id: client.client_id, client_secret: 'wrong_secret' },
               headers: headers
          json = response.parsed_body
          expect(json['valid']).to be false
        end
      end

      context '存在しない client_id の場合' do
        it '401 Unauthorized を返す' do
          post '/api/v1/clients/verify',
               params: { client_id: 'non-existent', client_secret: 'correct_secret' },
               headers: headers
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context '内部APIキーが不正または未指定の場合' do
      it '401 Unauthorized を返す' do
        post '/api/v1/clients/verify',
             params: { client_id: client.client_id, client_secret: 'correct_secret' },
             headers: { 'X-Internal-API-Key' => 'wrong-key' }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'ヘッダー未指定でも 401 Unauthorized を返す' do
        post '/api/v1/clients/verify',
             params: { client_id: client.client_id, client_secret: 'correct_secret' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
