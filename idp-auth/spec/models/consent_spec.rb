require 'spec_helper'

RSpec.describe Consent, type: :model do
  let(:user_id) { '550e8400-e29b-41d4-a716-446655440000' }
  let(:client_id) { '550e8400-e29b-41d4-a716-446655440001' }

  describe 'バリデーション' do
    it '全必須項目が揃っている場合は有効' do
      consent = described_class.record!(user_id: user_id, client_id: client_id, scope: 'openid profile')
      expect(consent).to be_valid
    end

    it 'user_id / client_id / scope が必須' do
      consent = described_class.new(user_id: nil, client_id: nil, scope: nil)
      expect(consent).not_to be_valid
      expect(consent.errors[:user_id]).to be_present
      expect(consent.errors[:client_id]).to be_present
      expect(consent.errors[:scope]).to be_present
    end

    it 'user_id と client_id の組は一意である' do
      described_class.record!(user_id: user_id, client_id: client_id, scope: 'openid')
      dup = described_class.new(user_id: user_id, client_id: client_id, scope: 'openid')
      expect(dup).not_to be_valid
      expect(dup.errors[:user_id]).to be_present
    end
  end

  describe '#scopes' do
    it '空白区切りの scope 文字列を配列に変換する' do
      consent = described_class.new(scope: 'openid profile email')
      expect(consent.scopes).to eq(%w[openid profile email])
    end

    it '前後の空白を無視する' do
      consent = described_class.new(scope: '  openid   profile  ')
      expect(consent.scopes).to eq(%w[openid profile])
    end
  end

  describe '#includes_scope?' do
    it '含まれる scope は true を返す' do
      consent = described_class.new(scope: 'openid profile')
      expect(consent.includes_scope?('openid')).to be true
      expect(consent.includes_scope?('email')).to be false
    end
  end

  describe '.record!' do
    it '新規登録時にレコードを作成する' do
      consent = described_class.record!(user_id: user_id, client_id: client_id, scope: 'openid')
      expect(consent).to be_persisted
      expect(consent.scope).to eq('openid')
    end

    it '同一 user/client が存在する場合は scope を更新する' do
      described_class.record!(user_id: user_id, client_id: client_id, scope: 'openid')
      updated = described_class.record!(user_id: user_id, client_id: client_id, scope: 'openid profile')
      expect(described_class.count).to eq(1)
      expect(updated.scope).to eq('openid profile')
    end
  end
end
