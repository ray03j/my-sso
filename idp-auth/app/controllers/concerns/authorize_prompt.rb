# /authorize の prompt（none / login）と max_age を扱う（OIDC Core §3.1.2.1, §15.1）
module AuthorizePrompt
  extend ActiveSupport::Concern

  PROMPT_NONE = 'none'.freeze
  PROMPT_LOGIN = 'login'.freeze

  private

  def prompts
    params[:prompt].to_s.split
  end

  def prompt_none?
    prompts.include?(PROMPT_NONE)
  end

  # none は他の値と同時に指定してはならない
  def validate_prompt!
    raise AuthorizeController::AuthorizeError, 'invalid_request' if prompt_none? && prompts.size > 1
  end

  # max_age は 0 以上の整数（秒）
  def validate_max_age!
    return if params[:max_age].nil?
    return if params[:max_age].to_s.match?(/\A\d+\z/)

    raise AuthorizeController::AuthorizeError, 'invalid_request'
  end

  # 未ログイン・prompt=login・max_age 超過のいずれかなら、ユーザーに認証を求める
  def reauthentication_required?
    return true unless authenticated?

    prompts.include?(PROMPT_LOGIN) || max_age_exceeded?
  end

  # 認証時刻が分からないセッションは、経過時間を判断できないため超過とみなす
  def max_age_exceeded?
    return false if params[:max_age].nil?
    return true if current_auth_time.nil?

    Time.current.to_i - current_auth_time > params[:max_age].to_i
  end

  # prompt=none では画面を表示してはならず、エラーで RP に返す
  def require_login
    raise AuthorizeController::AuthorizeError, 'login_required' if prompt_none?

    continue_at(login_url)
  end

  def require_consent
    raise AuthorizeController::AuthorizeError, 'consent_required' if prompt_none?

    continue_at(consent_url)
  end
end
