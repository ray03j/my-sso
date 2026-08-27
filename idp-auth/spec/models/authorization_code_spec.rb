require 'spec_helper'

RSpec.describe AuthorizationCode, type: :model do
  let(:user_id) { '550e8400-e29b-41d4-a716-446655440000' }
  let(:client_id) { '550e8400-e29b-41d4-a716-446655440001' }
  let(:redirect_uri) { 'http://localhost:5174/callback' }

  describe 'バリデーション' do
    it '全必須項目が揃っている場合は有効' do
      code = described_class.generate_for(
        user_id: user_id, client_id: client_id, redirect_uri: redirect_uri
      )
      expect(code).to be_valid
    end

    it 'code が必須' do
      code = described_class.new(
        code: nil, user_id: user_id, client_id: client_id,
        redirect_uri: redirect_uri, expires_at: 10.minutes.from_now
      )
      expect(code).not_to be_valid
      expect(code.errors[:code]).to be_present
    end

    it 'code は一意である' do
      existing = described_class.generate_for(
        user_id: user_id, client_id: client_id, redirect_uri: redirect_uri
      )
      dup = described_class.new(
        code: existing.code, user_id: user_id, client_id: client_id,
        redirect_uri: redirect_uri, expires_at: 10.minutes.from_now
      )
      expect(dup).not_to be_valid
      expect(dup.errors[:code]).to be_present
    end

    it 'user_id が必須' do
      code = described_class.new(
        code: 'c1', user_id: nil, client_id: client_id,
        redirect_uri: redirect_uri, expires_at: 10.minutes.from_now
      )
      expect(code).not_to be_valid
      expect(code.errors[:user_id]).to be_present
    end

    it 'client_id が必須' do
      code = described_class.new(
        code: 'c1', user_id: user_id, client_id: nil,
        redirect_uri: redirect_uri, expires_at: 10.minutes.from_now
      )
      expect(code).not_to be_valid
      expect(code.errors[:client_id]).to be_present
    end

    it 'redirect_uri が必須' do
      code = described_class.new(
        code: 'c1', user_id: user_id, client_id: client_id,
        redirect_uri: nil, expires_at: 10.minutes.from_now
      )
      expect(code).not_to be_valid
      expect(code.errors[:redirect_uri]).to be_present
    end

    it 'expires_at が必須' do
      code = described_class.new(
        code: 'c1', user_id: user_id, client_id: client_id,
        redirect_uri: redirect_uri, expires_at: nil
      )
      expect(code).not_to be_valid
      expect(code.errors[:expires_at]).to be_present
    end
  end

  describe '.generate_for' do
    it 'ランダムな code を発行し 10 分後に期限切れとなる' do
      code = described_class.generate_for(
        user_id: user_id, client_id: client_id, redirect_uri: redirect_uri
      )
      expect(code.code).to be_present
      expect(code.code.length).to be >= 32
      expect(code.scope).to eq('openid')
      expect(code.expires_at).to be_within(5.seconds).of(described_class::EXPIRES_IN.seconds.from_now)
      expect(code.used).to be false
    end
  end

  describe '#expired?' do
    it 'expires_at を過ぎると true を返す' do
      code = described_class.generate_for(
        user_id: user_id, client_id: client_id, redirect_uri: redirect_uri
      )
      expect(code.expired?).to be false

      code.update!(expires_at: 1.second.ago)
      expect(code.expired?).to be true
    end
  end

  describe '#used?' do
    it '初期状態は未使用' do
      code = described_class.generate_for(
        user_id: user_id, client_id: client_id, redirect_uri: redirect_uri
      )
      expect(code.used?).to be false

      code.update!(used: true)
      expect(code.used?).to be true
    end
  end
end
