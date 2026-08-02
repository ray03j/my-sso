require 'spec_helper'

RSpec.describe RefreshToken, type: :model do
  let(:user_id) { '550e8400-e29b-41d4-a716-446655440000' }
  let(:client_id) { '550e8400-e29b-41d4-a716-446655440001' }

  describe 'バリデーション' do
    it '全必須項目が揃っている場合は有効' do
      token = described_class.generate_for(user_id: user_id, client_id: client_id)
      expect(token).to be_valid
    end

    it 'token が必須' do
      token = described_class.new(token: nil, user_id: user_id, client_id: client_id)
      expect(token).not_to be_valid
      expect(token.errors[:token]).to be_present
    end

    it 'token は一意である' do
      existing = described_class.generate_for(user_id: user_id, client_id: client_id)
      dup = described_class.new(token: existing.token, user_id: user_id, client_id: client_id)
      expect(dup).not_to be_valid
      expect(dup.errors[:token]).to be_present
    end

    it 'user_id / client_id が必須' do
      token = described_class.new(token: 'rt1', user_id: nil, client_id: nil)
      expect(token).not_to be_valid
      expect(token.errors[:user_id]).to be_present
      expect(token.errors[:client_id]).to be_present
    end
  end

  describe '.generate_for' do
    it 'ランダムな token を発行し scope を保持する' do
      token = described_class.generate_for(user_id: user_id, client_id: client_id, scope: 'openid email')
      expect(token.token).to be_present
      expect(token.token.length).to be >= 32
      expect(token.scope).to eq('openid email')
    end
  end
end
