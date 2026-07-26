require 'spec_helper'

RSpec.describe ClientVerificationService do
  let!(:client) { create(:client, client_secret: 'correct_secret') }

  describe '.verify' do
    context '有効な client_id / client_secret の場合' do
      it 'valid: true を返す' do
        result = described_class.verify(client_id: client.client_id, client_secret: 'correct_secret')
        expect(result[:valid]).to be true
        expect(result[:client]).to eq(client)
      end
    end

    context '無効な client_secret の場合' do
      it 'valid: false を返す' do
        result = described_class.verify(client_id: client.client_id, client_secret: 'wrong_secret')
        expect(result[:valid]).to be false
        expect(result[:error]).to eq('invalid client_secret')
      end
    end

    context '存在しない client_id の場合' do
      it 'valid: false を返す' do
        result = described_class.verify(client_id: 'non-existent', client_secret: 'correct_secret')
        expect(result[:valid]).to be false
        expect(result[:error]).to eq('client not found')
      end
    end

    context 'client_id が空の場合' do
      it 'valid: false を返す' do
        result = described_class.verify(client_id: '', client_secret: 'correct_secret')
        expect(result[:valid]).to be false
        expect(result[:error]).to eq('client_id is required')
      end
    end

    context 'client_secret が空の場合' do
      it 'valid: false を返す' do
        result = described_class.verify(client_id: client.client_id, client_secret: '')
        expect(result[:valid]).to be false
        expect(result[:error]).to eq('client_secret is required')
      end
    end

    context 'redirect_uri が指定された場合' do
      it '登録済みの redirect_uri なら valid: true を返す' do
        result = described_class.verify(
          client_id: client.client_id,
          client_secret: 'correct_secret',
          redirect_uri: client.redirect_uris.first
        )
        expect(result[:valid]).to be true
      end

      it '未登録の redirect_uri なら valid: false を返す' do
        result = described_class.verify(
          client_id: client.client_id,
          client_secret: 'correct_secret',
          redirect_uri: 'http://evil.example/callback'
        )
        expect(result[:valid]).to be false
        expect(result[:error]).to eq('invalid redirect_uri')
      end
    end
  end
end
