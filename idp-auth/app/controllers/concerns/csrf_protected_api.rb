# ブラウザのセッションを読み書きする API では CSRF トークンを必須にする。
# null_session のままだと、トークンのないログインが 200 を返しつつセッションを保存しないため、422 で失敗を明示する
module CsrfProtectedApi
  extend ActiveSupport::Concern

  included do
    protect_from_forgery with: :exception

    rescue_from ActionController::InvalidAuthenticityToken do
      render json: { error: 'invalid_csrf_token' }, status: :unprocessable_content
    end
  end
end
