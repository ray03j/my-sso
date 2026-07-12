require 'rails_helper'

RSpec.describe User::PasswordService do
  describe 'パスワードをハッシュ化する (.hash)' do
    it '文字列の bcrypt ハッシュを生成する' do
      hash = described_class.hash('password123')
      expect(hash).to be_a(String)
      expect(hash).to start_with('$2a$')
    end

    it '同じ平文でも異なるハッシュを生成する（ソルト付き）' do
      hash1 = described_class.hash('password123')
      hash2 = described_class.hash('password123')
      expect(hash1).not_to eq(hash2)
    end
  end

  describe 'パスワードを検証する (.verify?)' do
    let(:password_digest) { BCrypt::Password.create('password123').to_s }

    it '正しいパスワードで true を返す' do
      expect(described_class.verify?('password123', password_digest)).to be true
    end

    it '誤ったパスワードで false を返す' do
      expect(described_class.verify?('wrongpassword', password_digest)).to be false
    end

    it '空のパスワードで false を返す' do
      expect(described_class.verify?('', password_digest)).to be false
    end

    it '空のハッシュで false を返す' do
      expect(described_class.verify?('password123', '')).to be false
    end

    it '不正なハッシュで false を返す' do
      expect(described_class.verify?('password123', 'invalid_digest')).to be false
    end
  end
end
