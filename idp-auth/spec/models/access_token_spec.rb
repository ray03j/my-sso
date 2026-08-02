require 'spec_helper'

RSpec.describe AccessToken, type: :model do
  let(:user_id) { '550e8400-e29b-41d4-a716-446655440000' }
  let(:client_id) { '550e8400-e29b-41d4-a716-446655440001' }

  describe 'バリデーション' do
    it '全必須項目が揃っている場合は有効' do
      token = described_class.generate_for(user_id: user_id, client_id: client_id)
      expect(token).to be_valid
    end

    it 'token が必須' do
      token = described_class.new(
        token: nil, user_id: user_id, client_id: client_id, expires_at: 15.minutes.from_now
      )
      expect(token).not_to be_valid
      expect(token.errors[:token]).to be_present
    end

    it 'token は一意である' do
      existing = described_class.generate_for(user_id: user_id, client_id: client_id)
      dup = described_class.new(
        token: existing.token, user_id: user_id, client_id: client_id,
        expires_at: 15.minutes.from_now
      )
      expect(dup).not_to be_valid
      expect(dup.errors[:token]).to be_present
    end

    it 'user_id / client_id / expires_at が必須' do
      token = described_class.new(token: 't1', user_id: nil, client_id: nil, expires_at: nil)
      expect(token).not_to be_valid
      expect(token.errors[:user_id]).to be_present
      expect(token.errors[:client_id]).to be_present
      expect(token.errors[:expires_at]).to be_present
    end
  end

  describe '.generate_for' do
    it 'ランダムな token を発行し 15 分後に期限切れとなる' do
      token = described_class.generate_for(user_id: user_id, client_id: client_id, scope: 'openid profile')
      expect(token.token).to be_present
      expect(token.scope).to eq('openid profile')
      expect(token.expires_at).to be_within(5.seconds).of(described_class::EXPIRES_IN.seconds.from_now)
    end
  end

  describe '#expired?' do
    it 'expires_at を過ぎると true を返す' do
      token = described_class.generate_for(user_id: user_id, client_id: client_id)
      expect(token.expired?).to be false

      token.update!(expires_at: 1.second.ago)
      expect(token.expired?).to be true
    end
  end
end
