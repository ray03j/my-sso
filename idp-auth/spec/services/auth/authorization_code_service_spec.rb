require 'rails_helper'

RSpec.describe Auth::AuthorizationCodeService do
  let(:code_challenge) { 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk' }
  let(:code_verifier) { 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk' }

  describe '.issue' do
    it '認可コードを発行する' do
      code = described_class.issue(
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        client_id: '550e8400-e29b-41d4-a716-446655440001',
        redirect_uri: 'http://localhost:5174/callback',
        code_challenge: code_challenge,
        code_challenge_method: 'S256'
      )

      expect(code).to be_persisted
      expect(code.code).to be_present
      expect(code.expires_at).to be_within(5.seconds).of(10.minutes.from_now)
      expect(code.code_challenge).to eq(code_challenge)
      expect(code.code_challenge_method).to eq('S256')
    end

    it '必須パラメータが欠落するとエラーになる' do
      expect do
        described_class.issue(
          user_id: nil,
          client_id: 'client-001',
          redirect_uri: 'http://localhost:5174/callback',
          code_challenge: code_challenge,
          code_challenge_method: 'S256'
        )
      end.to raise_error(Auth::AuthorizationCodeService::InvalidRequestError)
    end

    it 'code_challenge が欠落するとエラーになる' do
      expect do
        described_class.issue(
          user_id: '550e8400-e29b-41d4-a716-446655440000',
          client_id: '550e8400-e29b-41d4-a716-446655440001',
          redirect_uri: 'http://localhost:5174/callback',
          code_challenge: nil,
          code_challenge_method: 'S256'
        )
      end.to raise_error(Auth::AuthorizationCodeService::InvalidRequestError, 'code_challenge is required')
    end

    it 'code_challenge_method が S256 以外だとエラーになる' do
      expect do
        described_class.issue(
          user_id: '550e8400-e29b-41d4-a716-446655440000',
          client_id: '550e8400-e29b-41d4-a716-446655440001',
          redirect_uri: 'http://localhost:5174/callback',
          code_challenge: code_challenge,
          code_challenge_method: 'plain'
        )
      end.to raise_error(Auth::AuthorizationCodeService::InvalidRequestError, 'unsupported code_challenge_method')
    end
  end

  describe '.verify_pkce' do
    let!(:authorization_code) do
      AuthorizationCode.generate_for(
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        client_id: '550e8400-e29b-41d4-a716-446655440001',
        redirect_uri: 'http://localhost:5174/callback',
        code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false),
        code_challenge_method: 'S256'
      )
    end

    it '正しい code_verifier で検証を通す' do
      expect(
        described_class.verify_pkce(record: authorization_code, code_verifier: code_verifier)
      ).to be true
    end

    it '誤った code_verifier で検証を失敗させる' do
      expect(
        described_class.verify_pkce(record: authorization_code, code_verifier: 'wrong-verifier')
      ).to be false
    end

    it 'code_verifier が欠落すると失敗させる' do
      expect(
        described_class.verify_pkce(record: authorization_code, code_verifier: nil)
      ).to be false
    end

    it 'code_challenge_method が S256 以外だと失敗させる' do
      authorization_code.update!(code_challenge_method: 'plain')
      expect(
        described_class.verify_pkce(record: authorization_code, code_verifier: code_verifier)
      ).to be false
    end

    it 'code_challenge が未設定だと失敗させる' do
      authorization_code.update!(code_challenge: nil)
      expect(
        described_class.verify_pkce(record: authorization_code, code_verifier: code_verifier)
      ).to be false
    end
  end

  describe '.verify' do
    let!(:authorization_code) do
      AuthorizationCode.generate_for(
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        client_id: '550e8400-e29b-41d4-a716-446655440001',
        redirect_uri: 'http://localhost:5174/callback',
        code_challenge: code_challenge,
        code_challenge_method: 'S256'
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
        redirect_uri: 'http://localhost:5174/callback',
        code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false),
        code_challenge_method: 'S256'
      )
    end

    it 'PKCE 検証を通して認可コードを使用済みにする' do
      described_class.consume(
        code: authorization_code.code,
        client_id: authorization_code.client_id,
        redirect_uri: 'http://localhost:5174/callback',
        code_verifier: code_verifier
      )
      expect(authorization_code.reload.used?).to be true
    end

    it 'code_verifier が不一致の場合は使用済みにせず nil を返す' do
      result = described_class.consume(
        code: authorization_code.code,
        client_id: authorization_code.client_id,
        redirect_uri: 'http://localhost:5174/callback',
        code_verifier: 'wrong-verifier'
      )
      expect(result).to be_nil
      expect(authorization_code.reload.used?).to be false
    end

    it '一度使用した認可コードの再利用を拒否する' do
      consume_params = {
        code: authorization_code.code,
        client_id: authorization_code.client_id,
        redirect_uri: 'http://localhost:5174/callback',
        code_verifier: code_verifier
      }
      expect(described_class.consume(**consume_params)).to be_present

      expect(described_class.consume(**consume_params)).to be_nil
      expect(authorization_code.reload.used?).to be true
    end

    it '有効期限切れの認可コードは使用済みにせず nil を返す' do
      authorization_code.update!(expires_at: 1.second.ago)
      result = described_class.consume(
        code: authorization_code.code,
        client_id: authorization_code.client_id,
        redirect_uri: 'http://localhost:5174/callback',
        code_verifier: code_verifier
      )
      expect(result).to be_nil
      expect(authorization_code.reload.used?).to be false
    end
  end
end
