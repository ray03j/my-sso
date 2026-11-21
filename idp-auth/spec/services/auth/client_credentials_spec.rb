require 'rails_helper'

RSpec.describe Auth::ClientCredentials do
  let(:client_id) { '550e8400-e29b-41d4-a716-446655440001' }

  def basic(id, secret)
    "Basic #{Base64.strict_encode64("#{id}:#{secret}")}"
  end

  describe '.from' do
    context 'Authorization: Basic ヘッダがある場合' do
      it 'ヘッダから client_id と client_secret を取り出し client_secret_basic とする' do
        credentials = described_class.from(authorization: basic(client_id, 'correct_secret'), params: {})
        expect(credentials).to have_attributes(
          client_id: client_id, client_secret: 'correct_secret', auth_method: :client_secret_basic
        )
        expect(credentials).to be_basic
      end

      it 'form-urlencoded された値をデコードする（RFC 6749 §2.3.1）' do
        authorization = basic(CGI.escape('client:id'), CGI.escape('s3cr%t+:/'))
        credentials = described_class.from(authorization: authorization, params: {})
        expect(credentials).to have_attributes(client_id: 'client:id', client_secret: 's3cr%t+:/')
      end

      it 'ボディの client_id がヘッダと一致すれば受け付ける' do
        credentials = described_class.from(
          authorization: basic(client_id, 'correct_secret'), params: { client_id: client_id }
        )
        expect(credentials.client_id).to eq(client_id)
      end

      it 'ボディの client_id がヘッダと異なれば InvalidRequestError' do
        expect do
          described_class.from(authorization: basic(client_id, 'correct_secret'), params: { client_id: 'other' })
        end.to raise_error(described_class::InvalidRequestError)
      end

      it 'ボディにも client_secret があれば認証方式の重複として InvalidRequestError（RFC 6749 §2.3）' do
        expect do
          described_class.from(
            authorization: basic(client_id, 'correct_secret'), params: { client_secret: 'correct_secret' }
          )
        end.to raise_error(described_class::InvalidRequestError)
      end

      it 'Base64 として不正なら InvalidClientError' do
        expect do
          described_class.from(authorization: 'Basic !!!not-base64!!!', params: {})
        end.to raise_error(described_class::InvalidClientError)
      end

      it '":" を含まなければ InvalidClientError' do
        expect do
          described_class.from(authorization: "Basic #{Base64.strict_encode64(client_id)}", params: {})
        end.to raise_error(described_class::InvalidClientError)
      end

      it 'client_secret が空なら InvalidClientError' do
        expect do
          described_class.from(authorization: basic(client_id, ''), params: {})
        end.to raise_error(described_class::InvalidClientError)
      end
    end

    context 'Authorization ヘッダがない場合' do
      it 'ボディから client_id と client_secret を取り出し client_secret_post とする' do
        credentials = described_class.from(
          authorization: nil, params: { client_id: client_id, client_secret: 'correct_secret' }
        )
        expect(credentials).to have_attributes(
          client_id: client_id, client_secret: 'correct_secret', auth_method: :client_secret_post
        )
        expect(credentials).not_to be_basic
      end

      it 'client_secret がなければ InvalidRequestError' do
        expect do
          described_class.from(authorization: nil, params: { client_id: client_id })
        end.to raise_error(described_class::InvalidRequestError)
      end

      it 'client_id がなければ InvalidRequestError' do
        expect do
          described_class.from(authorization: nil, params: { client_secret: 'correct_secret' })
        end.to raise_error(described_class::InvalidRequestError)
      end
    end

    context 'Basic 以外の Authorization ヘッダの場合' do
      it 'ヘッダを無視してボディから取り出す' do
        credentials = described_class.from(
          authorization: 'Bearer token', params: { client_id: client_id, client_secret: 'correct_secret' }
        )
        expect(credentials.auth_method).to eq(:client_secret_post)
      end
    end
  end
end
