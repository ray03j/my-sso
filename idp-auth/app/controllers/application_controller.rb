class ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session

  private

  def current_session_user_id
    session[:user_id]
  end

  def assign_session_user(user_id)
    session[:user_id] = user_id
  end

  def clear_session_user
    session.delete(:user_id)
  end

  def authenticated?
    current_session_user_id.present?
  end
end
