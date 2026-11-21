class ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session

  private

  def current_session_user_id
    session[:user_id]
  end

  # 認証した時刻を保持し、max_age の判定と ID Token の auth_time に使う（OIDC Core §2, §3.1.2.1）
  def assign_session_user(user_id)
    session[:user_id] = user_id
    session[:auth_time] = Time.current.to_i
  end

  def clear_session_user
    session.delete(:user_id)
    session.delete(:auth_time)
  end

  def current_auth_time
    session[:auth_time]
  end

  def authenticated?
    current_session_user_id.present?
  end
end
