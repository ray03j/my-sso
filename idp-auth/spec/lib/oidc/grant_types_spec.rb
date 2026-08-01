require 'rails_helper'

RSpec.describe Oidc::GrantTypes do
  describe '.valid?' do
    it 'authorization_code は有効' do
      expect(described_class.valid?('authorization_code')).to be true
    end

    it 'refresh_token は有効' do
      expect(described_class.valid?('refresh_token')).to be true
    end

    it '未知の grant_type は無効' do
      expect(described_class.valid?('implicit')).to be false
    end
  end
end
