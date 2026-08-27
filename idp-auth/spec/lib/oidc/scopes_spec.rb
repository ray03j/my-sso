require 'rails_helper'

RSpec.describe Oidc::Scopes do
  describe '.valid?' do
    it 'openid profile email は有効' do
      expect(described_class.valid?('openid profile email')).to be true
    end

    it 'openid は有効' do
      expect(described_class.valid?('openid')).to be true
    end

    it '未知のスコープを含む場合は無効' do
      expect(described_class.valid?('openid address')).to be false
    end

    it '空文字列は有効' do
      expect(described_class.valid?('')).to be true
    end
  end

  describe '.parse' do
    it 'スペース区切りのスコープを配列に変換する' do
      expect(described_class.parse('openid profile email')).to eq(%w[openid profile email])
    end

    it '重複を除去する' do
      expect(described_class.parse('openid openid')).to eq(['openid'])
    end
  end

  describe '.join' do
    it '配列をスペース区切り文字列に変換する' do
      expect(described_class.join(%w[openid profile])).to eq('openid profile')
    end
  end
end
