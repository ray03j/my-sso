require 'rails_helper'

RSpec.describe 'Consent', type: :request do
  describe 'POST /api/v1/consent' do
    let(:user_id) { '550e8400-e29b-41d4-a716-446655440000' }
    let(:client_id) { '550e8400-e29b-41d4-a716-446655440001' }

    context 'ログイン済みの場合' do
      before do
        sign_in(user_id: user_id)
      end

      it '同意を記録する' do
        expect do
          post '/api/v1/consent', params: { client_id: client_id, scope: 'openid profile', approved: true }
        end.to change(Consent, :count).by(1)
      end

      it 'approved: true を返す' do
        post '/api/v1/consent', params: { client_id: client_id, scope: 'openid profile', approved: true }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['approved']).to be true
      end

      it 'approved: false の場合はレコードを作らない' do
        expect do
          post '/api/v1/consent', params: { client_id: client_id, scope: 'openid profile', approved: false }
        end.not_to change(Consent, :count)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['approved']).to be false
      end
    end

    context '未ログインの場合' do
      it '401 Unauthorized を返す' do
        post '/api/v1/consent', params: { client_id: client_id, scope: 'openid profile', approved: true }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
