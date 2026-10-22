require 'rails_helper'

RSpec.describe Auth::RefreshTokenService do
  let(:user_id) { '550e8400-e29b-41d4-a716-446655440000' }
  let(:client_id) { '550e8400-e29b-41d4-a716-446655440001' }

  describe '.consume' do
    let!(:record) do
      RefreshToken.generate_for(user_id: user_id, client_id: client_id, scope: 'openid profile')
    end

    it '旧トークンを失効させ、新しいリフレッシュトークンを発行する（回転）' do
      new_record = described_class.consume(token: record.token, client_id: client_id)

      expect(new_record).to be_present
      expect(new_record.token).not_to eq(record.token)
      expect(record.reload).to be_revoked
      expect(new_record).not_to be_revoked
    end

    it '回転後も user_id / client_id / scope を引き継ぐ' do
      new_record = described_class.consume(token: record.token, client_id: client_id)

      expect(new_record.user_id).to eq(user_id)
      expect(new_record.client_id).to eq(client_id)
      expect(new_record.scope).to eq('openid profile')
    end

    it '要求スコープが元の付与の部分集合なら狭めて発行する' do
      new_record = described_class.consume(token: record.token, client_id: client_id, scope: 'openid')

      expect(new_record.scope).to eq('openid')
    end

    it '要求スコープが元の付与を超える場合は InvalidScopeError を投げる' do
      expect do
        described_class.consume(token: record.token, client_id: client_id, scope: 'openid email')
      end.to raise_error(Auth::RefreshTokenService::InvalidScopeError)
    end

    it '存在しないトークンの場合は nil を返す' do
      expect(described_class.consume(token: 'unknown', client_id: client_id)).to be_nil
    end

    it 'client_id が一致しない場合は nil を返す' do
      expect(described_class.consume(token: record.token, client_id: 'other-client')).to be_nil
    end

    it '期限切れのトークンの場合は nil を返す' do
      record.update!(expires_at: 1.second.ago)

      expect(described_class.consume(token: record.token, client_id: client_id)).to be_nil
    end

    it '失効済みトークンの再提示では族ごと失効させる（再利用検知）' do
      new_record = described_class.consume(token: record.token, client_id: client_id)

      result = described_class.consume(token: record.token, client_id: client_id)

      expect(result).to be_nil
      expect(new_record.reload).to be_revoked
    end
  end
end
