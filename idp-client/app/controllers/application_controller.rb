class ApplicationController < ActionController::API
  private

  # 内部APIとして公開するコントローラで before_action として明示的に宣言する
  # （宣言漏れによる認証なし公開を防ぐため、デフォルト適用のフックは設けない）
  def require_internal_api_key
    expected = ENV.fetch('INTERNAL_API_KEY', nil)
    provided = request.headers['X-Internal-API-Key']

    return render json: { error: 'Unauthorized' }, status: :unauthorized if expected.blank? || provided.blank?
    return if provided == expected

    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
end
