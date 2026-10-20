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

    context 'idp-user へ接続できない場合' do
      it '接続拒否では例外を外部に漏らさず nil を返す' do
        allow(HTTParty).to receive(:post).and_raise(Errno::ECONNREFUSED)
        expect(described_class.authenticate('test@example.com', 'password123')).to be_nil
      end

      it 'HTTPartyのエラーでは例外を外部に漏らさず nil を返す' do
        allow(HTTParty).to receive(:post).and_raise(HTTParty::Error)
        expect(described_class.authenticate('test@example.com', 'password123')).to be_nil
      end

      it '接続拒否を例外クラスのみでログに記録する' do
        allow(Rails.logger).to receive(:warn)
        allow(HTTParty).to receive(:post).and_raise(Errno::ECONNREFUSED)

        expect(described_class.authenticate('test@example.com', 'password123')).to be_nil

        expect(Rails.logger).to have_received(:warn).with(a_string_including('Errno::ECONNREFUSED'))
        expect(Rails.logger).not_to have_received(:warn).with(a_string_including('test@example.com'))
        expect(Rails.logger).not_to have_received(:warn).with(a_string_including('password123'))
      end
    end
  end
end
