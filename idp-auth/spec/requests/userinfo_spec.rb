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

      it 'sub / email / name を返す' do
        get '/userinfo', headers: { 'Authorization' => "Bearer #{access_token}" }
        json = response.parsed_body
        expect(json).to include('sub', 'email', 'name')
        expect(json['sub']).to eq(user_id)
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
    end

    context '無効な Bearer トークンの場合' do
      it '401 Unauthorized を返す' do
        get '/userinfo', headers: { 'Authorization' => 'Bearer invalid.token.value' }
        expect(response).to have_http_status(:unauthorized)
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
end
