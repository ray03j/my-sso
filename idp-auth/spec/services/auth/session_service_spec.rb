require 'rails_helper'

RSpec.describe Auth::SessionService do
  describe '.authenticate' do
    let(:verify_url) { described_class.idp_user_verify_url }

    context 'idp-user が認証成功を返す場合' do
      before do
        stub_request(:post, verify_url)
          .with(
            body: { email: 'test@example.com', password: 'password123' }.to_json,
            headers: { 'X-Internal-API-Key' => described_class.internal_api_key }
          )
          .to_return(
            status: 200,
            body: { user: { id: 1, email: 'test@example.com', name: 'Test' } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'ユーザー情報を返す' do
        user = described_class.authenticate('test@example.com', 'password123')
        expect(user).to include('id' => 1, 'email' => 'test@example.com', 'name' => 'Test')
      end
    end

    context 'idp-user が認証失敗を返す場合' do
      before do
        stub_request(:post, verify_url)
          .to_return(
            status: 401,
            body: { code: 'INVALID_CREDENTIALS' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'nil を返す' do
        user = described_class.authenticate('test@example.com', 'wrongpassword')
        expect(user).to be_nil
      end
    end

    context 'idp-user がタイムアウトする場合' do
      before do
        stub_request(:post, verify_url)
          .to_timeout
      end

      it 'nil を返す' do
        user = described_class.authenticate('test@example.com', 'password123')
        expect(user).to be_nil
      end
    end
  end
end
