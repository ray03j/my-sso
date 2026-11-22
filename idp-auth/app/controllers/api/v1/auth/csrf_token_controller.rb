module Api
  module V1
    module Auth
      # フロントエンドがログイン・同意・ログアウトの API に付ける CSRF トークンを返す。
      # トークンはセッションに紐づくため、このレスポンスでセッション Cookie も発行する
      class CsrfTokenController < ApplicationController
        def show
          render json: { csrf_token: form_authenticity_token }
        end
      end
    end
  end
end
