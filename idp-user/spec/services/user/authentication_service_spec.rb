require 'rails_helper'

RSpec.describe User::AuthenticationService do
  let!(:user) { create(:user, email: 'test@example.com', password: 'password123') }

  describe 'ユーザーを認証する (.authenticate)' do
    context '正しいメール・パスワードの場合' do
      it 'ユーザーを返す' do
        result = described_class.authenticate('test@example.com', 'password123')
        expect(result).to eq(user)
      end
    end

    context '誤ったパスワードの場合' do
      it 'nil を返す' do
        result = described_class.authenticate('test@example.com', 'wrongpassword')
        expect(result).to be_nil
      end
    end

    context '存在しないメールの場合' do
      it 'nil を返す' do
        result = described_class.authenticate('nonexistent@example.com', 'password123')
        expect(result).to be_nil
      end
    end
  end
end
