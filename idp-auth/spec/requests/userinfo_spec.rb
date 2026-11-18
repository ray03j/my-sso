require 'rails_helper'

RSpec.describe 'Userinfo', type: :request do
  let(:user_id) { '550e8400-e29b-41d4-a716-446655440000' }
  let(:client_id) { '550e8400-e29b-41d4-a716-446655440001' }
  let(:user_attrs) { { 'id' => user_id, 'email' => 'test@example.com', 'name' => 'Test User' } }
  let(:access_token) { Auth::TokenService.issue_access_token(user_id: user_id, client_id: client_id, scope: 'openid') }

  before do
    allow(HTTParty).to receive(:get).and_return(
      double(success?: true, parsed_response: user_attrs)
    )
  end

  describe 'GET /userinfo' do
    context '有効な Bearer トークンの場合' do
      it '200 OK を返す' do
        get '/userinfo', headers: { 'Authorization' => "Bearer #{access_token}" }
        expect(response).to have_http_status(:ok)
      end

      it 'openid のみのスコープでは sub だけを返す' do
        get '/userinfo', headers: { 'Authorization' => "Bearer #{access_token}" }
        expect(response.parsed_body).to eq('sub' => user_id)
      end
    end

    context 'スコープに応じたクレームの場合' do
      def userinfo_with(scope)
        token = Auth::TokenService.issue_access_token(user_id: user_id, client_id: client_id, scope: scope)
        get '/userinfo', headers: { 'Authorization' => "Bearer #{token}" }
        response.parsed_body
      end

      it 'profile を含むと name を返す' do
        expect(userinfo_with('openid profile')).to eq('sub' => user_id, 'name' => 'Test User')
      end

      it 'email を含むと email を返す' do
        expect(userinfo_with('openid email')).to eq('sub' => user_id, 'email' => 'test@example.com')
      end

      it 'profile と email を含むと name と email を返す' do
        expect(userinfo_with('openid profile email'))
          .to eq('sub' => user_id, 'name' => 'Test User', 'email' => 'test@example.com')
      end
    end

    context 'openid スコープを含まないトークンの場合' do
      let(:non_oidc_token) do
        Auth::TokenService.issue_access_token(user_id: user_id, client_id: client_id, scope: 'profile email')
      end

      it '403 Forbidden と error=insufficient_scope を返す' do
        get '/userinfo', headers: { 'Authorization' => "Bearer #{non_oidc_token}" }
        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['error']).to eq('insufficient_scope')
      end

      it 'WWW-Authenticate に insufficient_scope を返す' do
        get '/userinfo', headers: { 'Authorization' => "Bearer #{non_oidc_token}" }
        expect(response.headers['WWW-Authenticate']).to eq('Bearer error="insufficient_scope", scope="openid"')
      end

      it 'idp-user にユーザー情報を問い合わせない' do
        get '/userinfo', headers: { 'Authorization' => "Bearer #{non_oidc_token}" }
        expect(HTTParty).not_to have_received(:get)
      end
    end

    context 'Bearer トークンがない場合' do
      it '401 Unauthorized を返す' do
        get '/userinfo'
        expect(response).to have_http_status(:unauthorized)
      end

      it 'error=invalid_token を返す' do
        get '/userinfo'
        expect(response.parsed_body['error']).to eq('invalid_token')
      end

      it 'error 属性なしの WWW-Authenticate: Bearer を返す' do
        get '/userinfo'
        expect(response.headers['WWW-Authenticate']).to eq('Bearer')
      end
    end

    context '無効な Bearer トークンの場合' do
      it '401 Unauthorized を返す' do
        get '/userinfo', headers: { 'Authorization' => 'Bearer invalid.token.value' }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'WWW-Authenticate: Bearer error="invalid_token" を返す' do
        get '/userinfo', headers: { 'Authorization' => 'Bearer invalid.token.value' }
        expect(response.headers['WWW-Authenticate']).to eq('Bearer error="invalid_token"')
      end
    end

    context '期限切れのトークンの場合' do
      let(:expired_token) do
        Oidc::JwtSigner.sign(
          { sub: user_id, client_id: client_id, scope: 'openid',
            iat: 2.hours.ago.to_i, exp: 1.hour.ago.to_i }
        )
      end

      it '401 Unauthorized を返す' do
        get '/userinfo', headers: { 'Authorization' => "Bearer #{expired_token}" }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'error=invalid_token を返す' do
        get '/userinfo', headers: { 'Authorization' => "Bearer #{expired_token}" }
        expect(response.parsed_body['error']).to eq('invalid_token')
      end

      it 'WWW-Authenticate: Bearer error="invalid_token" を返す' do
        get '/userinfo', headers: { 'Authorization' => "Bearer #{expired_token}" }
        expect(response.headers['WWW-Authenticate']).to eq('Bearer error="invalid_token"')
      end
    end

    context '異なるシークレットで署名されたトークンの場合' do
      let(:forged_token) do
        JWT.encode(
          { sub: user_id, client_id: client_id, scope: 'openid',
            iat: Time.current.to_i, exp: 1.hour.from_now.to_i },
          'wrong-secret', 'HS256'
        )
      end

      it '401 Unauthorized を返す' do
        get '/userinfo', headers: { 'Authorization' => "Bearer #{forged_token}" }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'error=invalid_token を返す' do
        get '/userinfo', headers: { 'Authorization' => "Bearer #{forged_token}" }
        expect(response.parsed_body['error']).to eq('invalid_token')
      end
    end

    context 'Authorization ヘッダが Bearer 形式でない場合' do
      it '401 Unauthorized を返す' do
        get '/userinfo', headers: { 'Authorization' => "Basic #{access_token}" }
        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body['error']).to eq('invalid_token')
      end

      it 'Bearer トークンがないものとして WWW-Authenticate: Bearer を返す' do
        get '/userinfo', headers: { 'Authorization' => "Basic #{access_token}" }
        expect(response.headers['WWW-Authenticate']).to eq('Bearer')
      end
    end

    context 'idp-user がユーザーを見つけられない場合' do
      before do
        allow(HTTParty).to receive(:get).and_return(
          double(success?: false, parsed_response: {})
        )
      end

      it '401 Unauthorized を返す' do
        get '/userinfo', headers: { 'Authorization' => "Bearer #{access_token}" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'idp-user がタイムアウト・接続障害した場合' do
      before do
        allow(HTTParty).to receive(:get).and_raise(Net::ReadTimeout)
      end

      it '401 Unauthorized を返す' do
        get '/userinfo', headers: { 'Authorization' => "Bearer #{access_token}" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /userinfo' do
    context '有効な Bearer トークンの場合' do
      it '200 OK を返す' do
        post '/userinfo', headers: { 'Authorization' => "Bearer #{access_token}" }
        expect(response).to have_http_status(:ok)
      end

      it 'GET と同じくスコープに応じたクレームを返す' do
        token = Auth::TokenService.issue_access_token(user_id: user_id, client_id: client_id,
                                                      scope: 'openid profile email')
        post '/userinfo', headers: { 'Authorization' => "Bearer #{token}" }
        expect(response.parsed_body).to eq('sub' => user_id, 'name' => 'Test User', 'email' => 'test@example.com')
      end

      it 'CSRF トークンなしのフォーム送信でも 200 OK を返す' do
        post '/userinfo', params: {}, headers: {
          'Authorization' => "Bearer #{access_token}",
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'Bearer トークンがない場合' do
      it '401 Unauthorized と WWW-Authenticate: Bearer を返す' do
        post '/userinfo'
        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['WWW-Authenticate']).to eq('Bearer')
      end
    end

    context '無効な Bearer トークンの場合' do
      it '401 Unauthorized と WWW-Authenticate: Bearer error="invalid_token" を返す' do
        post '/userinfo', headers: { 'Authorization' => 'Bearer invalid.token.value' }
        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['WWW-Authenticate']).to eq('Bearer error="invalid_token"')
      end
    end

    context 'openid スコープを含まないトークンの場合' do
      it '403 Forbidden と error=insufficient_scope を返す' do
        token = Auth::TokenService.issue_access_token(user_id: user_id, client_id: client_id, scope: 'profile email')
        post '/userinfo', headers: { 'Authorization' => "Bearer #{token}" }
        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['error']).to eq('insufficient_scope')
      end
    end
  end
end
