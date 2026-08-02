require 'rails_helper'

RSpec.describe Auth::AuthorizationCodeService do
  describe '.issue' do
    it '認可コードを発行する' do
      code = described_class.issue(
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        client_id: '550e8400-e29b-41d4-a716-446655440001',
        redirect_uri: 'http://localhost:5174/callback'
      )

      expect(code).to be_persisted
      expect(code.code).to be_present
      expect(code.expires_at).to be_within(5.seconds).of(10.minutes.from_now)
    end

    it '必須パラメータが欠落するとエラーになる' do
      expect do
        described_class.issue(
          user_id: nil,
          client_id: 'client-001',
          redirect_uri: 'http://localhost:5174/callback'
        )
      end.to raise_error(Auth::AuthorizationCodeService::InvalidRequestError)
    end
  end

  describe '.verify' do
    let!(:authorization_code) do
      AuthorizationCode.generate_for(
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        client_id: '550e8400-e29b-41d4-a716-446655440001',
        redirect_uri: 'http://localhost:5174/callback'
      )
    end

    it '正しいパラメータで認可コードを検証する' do
      result = described_class.verify(
        code: authorization_code.code,
        client_id: authorization_code.client_id,
        redirect_uri: 'http://localhost:5174/callback'
      )
      expect(result).to eq(authorization_code)
    end

    it '有効期限切れのコードを拒否する' do
      authorization_code.update!(expires_at: 1.second.ago)
      result = described_class.verify(
        code: authorization_code.code,
        client_id: authorization_code.client_id,
        redirect_uri: 'http://localhost:5174/callback'
      )
      expect(result).to be_nil
    end

    it '使用済みのコードを拒否する' do
      authorization_code.update!(used: true)
      result = described_class.verify(
        code: authorization_code.code,
        client_id: authorization_code.client_id,
        redirect_uri: 'http://localhost:5174/callback'
      )
      expect(result).to be_nil
    end

    it 'client_id が一致しないコードを拒否する' do
      result = described_class.verify(
        code: authorization_code.code,
        client_id: '550e8400-e29b-41d4-a716-446655440002',
        redirect_uri: 'http://localhost:5174/callback'
      )
      expect(result).to be_nil
    end

    it 'redirect_uri が一致しないコードを拒否する' do
      result = described_class.verify(
        code: authorization_code.code,
        client_id: authorization_code.client_id,
        redirect_uri: 'http://evil.example/callback'
      )
      expect(result).to be_nil
    end
  end

  describe '.consume' do
    let!(:authorization_code) do
      AuthorizationCode.generate_for(
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        client_id: '550e8400-e29b-41d4-a716-446655440001',
        redirect_uri: 'http://localhost:5174/callback'
      )
    end

    it '認可コードを検証後に使用済みにする' do
      described_class.consume(
        code: authorization_code.code,
        client_id: authorization_code.client_id,
        redirect_uri: 'http://localhost:5174/callback'
      )
      expect(authorization_code.reload.used?).to be true
    end
  end
end
