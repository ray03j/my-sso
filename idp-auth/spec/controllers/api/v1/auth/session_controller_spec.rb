require 'rails_helper'

RSpec.describe Api::V1::Auth::SessionController, type: :controller do
  describe 'POST create' do
    before do
      stub_request(:post, Auth::SessionService.idp_user_verify_url)
        .to_return(
          status: 200,
          body: { user: { id: 1, email: 'test@example.com', name: 'Test' } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'ログイン成功時に既存のセッションデータを破棄する（セッション固定対策）' do
      session[:attack_marker] = 'evil'

      post :create, params: { email: 'test@example.com', password: 'password123' }

      expect(response).to have_http_status(:ok)
      expect(session[:user_id]).to eq(1)
      expect(session[:attack_marker]).to be_nil
    end
  end
end
