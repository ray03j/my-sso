require 'rails_helper'

RSpec.describe 'End Session', type: :request do
  let(:user_id) { '550e8400-e29b-41d4-a716-446655440000' }
  let(:client_id) { '550e8400-e29b-41d4-a716-446655440001' }
  let(:post_logout_redirect_uri) { 'http://localhost:5174/' }
  let(:client) do
    { 'client_id' => client_id, 'post_logout_redirect_uris' => [post_logout_redirect_uri] }
  end
  let(:id_token) { Auth::TokenService.issue_id_token(user_id: user_id, client_id: client_id) }
  let(:valid_params) do
    { id_token_hint: id_token, post_logout_redirect_uri: post_logout_redirect_uri, state: 'xyz' }
  end

  before do
    allow(HTTParty).to receive(:get).and_return(double(success?: true, parsed_response: client))
    sign_in(user_id: user_id)
  end

  describe 'GET /end_session' do
    context '有効な id_token_hint と登録済みの post_logout_redirect_uri の場合' do
      it 'post_logout_redirect_uri に state を付けて戻すこと' do
        get '/end_session', params: valid_params
        expect(response).to redirect_to('http://localhost:5174/?state=xyz')
      end

      it 'IdP のセッションを消すこと' do
        expect_any_instance_of(EndSessionController).to receive(:reset_session).and_call_original
        get '/end_session', params: valid_params
      end
    end

    it '期限切れの id_token_hint でもログアウトできること' do
      expired = Oidc::JwtSigner.sign(
        iss: Oidc::Discovery::ISSUER, sub: user_id, aud: client_id, iat: 2.hours.ago.to_i, exp: 1.hour.ago.to_i
      )
      get '/end_session', params: valid_params.merge(id_token_hint: expired)
      expect(response).to redirect_to('http://localhost:5174/?state=xyz')
    end

    it 'post_logout_redirect_uri がなければログアウトして完了を表示すること' do
      get '/end_session', params: { id_token_hint: id_token }
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('ログアウトしました。')
    end

    it 'id_token_hint の sub が今のユーザーと違えば、セッションを消さないこと' do
      other = Auth::TokenService.issue_id_token(user_id: '550e8400-e29b-41d4-a716-446655440099', client_id: client_id)
      expect_any_instance_of(EndSessionController).not_to receive(:reset_session)
      get '/end_session', params: valid_params.merge(id_token_hint: other)
      expect(response).to redirect_to('http://localhost:5174/?state=xyz')
    end

    context '要求が不正な場合' do
      it 'id_token_hint がなければ 400 を返し、ログアウトしないこと' do
        expect_any_instance_of(EndSessionController).not_to receive(:reset_session)
        get '/end_session', params: valid_params.except(:id_token_hint)
        expect(response).to have_http_status(:bad_request)
      end

      it '署名が不正な id_token_hint なら 400 を返すこと' do
        get '/end_session', params: valid_params.merge(id_token_hint: "#{id_token}x")
        expect(response).to have_http_status(:bad_request)
      end

      it '登録されていない post_logout_redirect_uri なら、リダイレクトせず 400 を返すこと' do
        get '/end_session', params: valid_params.merge(post_logout_redirect_uri: 'https://evil.example.com/')
        expect(response).to have_http_status(:bad_request)
      end

      it 'client_id が id_token_hint の aud と違えば 400 を返すこと' do
        get '/end_session', params: valid_params.merge(client_id: '550e8400-e29b-41d4-a716-446655440002')
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'POST /end_session' do
    it 'CSRF トークンなしのフォーム送信でも post_logout_redirect_uri に戻すこと', :forgery_protection do
      post '/end_session', params: valid_params
      expect(response).to redirect_to('http://localhost:5174/?state=xyz')
    end
  end
end
