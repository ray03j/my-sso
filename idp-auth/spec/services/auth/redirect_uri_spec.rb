require 'rails_helper'

RSpec.describe Auth::RedirectUri do
  describe '.build' do
    it 'パラメータをクエリに付けること' do
      expect(described_class.build('http://localhost:5174/callback', code: 'c1', state: 's1'))
        .to eq('http://localhost:5174/callback?code=c1&state=s1')
    end

    it '元のクエリを保つこと' do
      expect(described_class.build('http://localhost:5174/callback?tenant=a', error: 'access_denied'))
        .to eq('http://localhost:5174/callback?tenant=a&error=access_denied')
    end

    it '空の値は付けないこと' do
      expect(described_class.build('http://localhost:5174/callback', error: 'access_denied', state: nil))
        .to eq('http://localhost:5174/callback?error=access_denied')
    end
  end
end
