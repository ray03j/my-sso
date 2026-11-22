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

      context 'approved=true で必須パラメータが欠落している場合' do
        it 'client_id が空なら 400 を返す' do
          post '/api/v1/consent', params: { scope: 'openid profile', approved: true }
          expect(response).to have_http_status(:bad_request)
        end

        it 'scope が空なら 400 を返す' do
          post '/api/v1/consent', params: { client_id: client_id, approved: true }
          expect(response).to have_http_status(:bad_request)
        end
      end

      it '同一クライアントへの再同意はスコープを上書きする' do
        post '/api/v1/consent', params: { client_id: client_id, scope: 'openid profile', approved: true }
        post '/api/v1/consent', params: { client_id: client_id, scope: 'openid profile email', approved: true }

        expect(Consent.count).to eq(1)
        expect(Consent.last.scope).to eq('openid profile email')
      end

      it 'スコープの前後の空白は除去して記録される' do
        post '/api/v1/consent', params: { client_id: client_id, scope: '  openid profile  ', approved: true }
        expect(Consent.last.scope).to eq('openid profile')
      end

      it '連続する空白・タブ・改行は単一スペースに正規化して記録される' do
        post '/api/v1/consent', params: { client_id: client_id, scope: "openid\t profile\r\n email", approved: true }
        expect(Consent.last.scope).to eq('openid profile email')
      end

      it '空白のみのスコープは 400 を返し記録しない' do
        expect do
          post '/api/v1/consent', params: { client_id: client_id, scope: '   ', approved: true }
        end.not_to change(Consent, :count)
        expect(response).to have_http_status(:bad_request)
      end
    end

    context '/authorize が同意のために中断していた場合' do
      let(:authorize_params) do
        {
          response_type: 'code', client_id: client_id, redirect_uri: 'http://localhost:5174/callback',
          scope: 'openid profile', state: 'abc123',
          code_challenge: 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk', code_challenge_method: 'S256'
        }
      end

      before do
        registered = {
          'client_id' => client_id,
          'redirect_uris' => ['http://localhost:5174/callback'],
          'allowed_scopes' => %w[openid profile email]
        }
        allow(HTTParty).to receive(:get).and_return(double(success?: true, parsed_response: registered))
        sign_in(user_id: user_id)
        get '/authorize', params: authorize_params
      end

      it '承認すると、認可を再開する /authorize/continue を返すこと' do
        post '/api/v1/consent', params: { client_id: client_id, scope: 'openid profile', approved: true }
        expect(response.parsed_body['redirect_to']).to eq("#{Oidc::Discovery::ISSUER}/authorize/continue")
      end

      it '拒否すると、RP の redirect_uri に error=access_denied と state を付けて返すこと' do
        post '/api/v1/consent', params: { client_id: client_id, scope: 'openid profile', approved: false }
        expect(response.parsed_body['redirect_to'])
          .to eq('http://localhost:5174/callback?error=access_denied&state=abc123')
      end

      it '拒否すると、保存したパラメータを消すこと' do
        post '/api/v1/consent', params: { client_id: client_id, scope: 'openid profile', approved: false }
        expect(session[:authorize_params]).to be_nil
      end
    end

    it '中断したリクエストがなければ redirect_to は null であること' do
      sign_in(user_id: user_id)
      post '/api/v1/consent', params: { client_id: client_id, scope: 'openid profile', approved: true }
      expect(response.parsed_body).to include('redirect_to' => nil)
    end

    context '未ログインの場合' do
      it '401 Unauthorized を返す' do
        post '/api/v1/consent', params: { client_id: client_id, scope: 'openid profile', approved: true }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
