require 'spec_helper'

RSpec.describe Client, type: :model do
  describe 'バリデーション' do
    it '全必須項目が揃っている場合は有効' do
      client = build(:client)
      expect(client).to be_valid
    end

    it 'client_id が必須' do
      client = build(:client, client_id: nil)
      expect(client).not_to be_valid
      expect(client.errors[:client_id]).to be_present
    end

    it 'client_id は一意である' do
      duplicate_id = SecureRandom.uuid
      create(:client, client_id: duplicate_id)
      client = build(:client, client_id: duplicate_id)
      expect(client).not_to be_valid
      expect(client.errors[:client_id]).to be_present
    end

    it 'name が必須' do
      client = build(:client, name: nil)
      expect(client).not_to be_valid
    end

    it 'redirect_uris に無効な URL を許可しない' do
      client = build(:client, redirect_uris: ['not-a-url'])
      expect(client).not_to be_valid
      expect(client.errors[:redirect_uris]).to be_present
    end

    it 'allowed_scopes にサポート外スコープを許可しない' do
      client = build(:client, allowed_scopes: %w[openid admin])
      expect(client).not_to be_valid
      expect(client.errors[:allowed_scopes]).to be_present
    end

    it 'client_secret が保存時に client_secret_hash へハッシュ化される' do
      client = Client.new(
        client_id: SecureRandom.uuid,
        name: 'Test',
        redirect_uris: ['http://localhost/callback'],
        allowed_scopes: ['openid']
      )
      client.client_secret = 'raw_secret'
      client.save!
      expect(client.client_secret_hash).to be_present
      expect(client.client_secret_valid?('raw_secret')).to be true
      expect(client.client_secret_valid?('wrong_secret')).to be false
    end
  end

  describe 'redirect_uris の境界値' do
    it 'https URL は有効' do
      client = build(:client, redirect_uris: ['https://app.example.com/callback'])
      expect(client).to be_valid
    end

    it 'スキームのみ（http://）の URL は無効' do
      client = build(:client, redirect_uris: ['http://'])
      expect(client).not_to be_valid
      expect(client.errors[:redirect_uris]).to be_present
    end

    it 'ftp スキームの URL は無効' do
      client = build(:client, redirect_uris: ['ftp://example.com/callback'])
      expect(client).not_to be_valid
      expect(client.errors[:redirect_uris]).to be_present
    end

    it 'javascript 疑似スキームは無効' do
      client = build(:client, redirect_uris: ['javascript:alert(1)'])
      expect(client).not_to be_valid
      expect(client.errors[:redirect_uris]).to be_present
    end

    it 'URL の配列が空の場合は無効' do
      client = build(:client, redirect_uris: [])
      expect(client).not_to be_valid
      expect(client.errors[:redirect_uris]).to be_present
    end

    it '空白のみの URL は無効' do
      client = build(:client, redirect_uris: ['   '])
      expect(client).not_to be_valid
      expect(client.errors[:redirect_uris]).to be_present
    end

    it '複数 URL のうち 1 つでも不正なら無効' do
      client = build(:client, redirect_uris: ['https://app.example.com/callback', 'not-a-url'])
      expect(client).not_to be_valid
      expect(client.errors[:redirect_uris]).to be_present
    end

    it 'CRLF 区切りと前後の空白が正規化される' do
      client = create(:client, redirect_uris: ["  https://a.example.com/cb \r\n https://b.example.com/cb  "])
      expect(client.redirect_uris).to eq(['https://a.example.com/cb', 'https://b.example.com/cb'])
    end
  end

  describe 'allowed_scopes の境界値と組み合わせ' do
    it '全サポートスコープの組み合わせは有効' do
      client = build(:client, allowed_scopes: %w[openid profile email])
      expect(client).to be_valid
    end

    it '大文字のスコープは無効' do
      client = build(:client, allowed_scopes: %w[OPENID])
      expect(client).not_to be_valid
      expect(client.errors[:allowed_scopes]).to be_present
    end

    it 'カンマ区切りのスコープは無効' do
      client = build(:client, allowed_scopes: ['openid,profile'])
      expect(client).not_to be_valid
      expect(client.errors[:allowed_scopes]).to be_present
    end

    it 'スコープが空配列の場合は無効' do
      client = build(:client, allowed_scopes: [])
      expect(client).not_to be_valid
      expect(client.errors[:allowed_scopes]).to be_present
    end

    it '空白のみのスコープは無効' do
      client = build(:client, allowed_scopes: ['   '])
      expect(client).not_to be_valid
      expect(client.errors[:allowed_scopes]).to be_present
    end

    it '連続する空白で区切られたスコープが正規化される' do
      client = create(:client, allowed_scopes: ['openid    profile'])
      expect(client.allowed_scopes).to eq(%w[openid profile])
    end

    it '重複したスコープは一意に正規化される' do
      client = create(:client, allowed_scopes: %w[openid profile openid])
      expect(client.allowed_scopes).to eq(%w[openid profile])
      expect(client.read_attribute(:allowed_scopes)).to eq('openid profile')
    end
  end

  describe '配列変換' do
    it 'redirect_uris を配列として読み書きできる' do
      client = create(:client, redirect_uris: ['http://a/callback', 'http://b/callback'])
      expect(client.redirect_uris).to eq(['http://a/callback', 'http://b/callback'])
    end

    it 'allowed_scopes を配列として読み書きできる' do
      client = create(:client, allowed_scopes: %w[openid email])
      expect(client.allowed_scopes).to eq(%w[openid email])
    end
  end
end
