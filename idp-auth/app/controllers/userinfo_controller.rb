require 'httparty'

class UserinfoController < ApplicationController
  def show
    token = bearer_token
    return render_token_error if token.blank?

    payload = Auth::TokenService.verify_access_token(token)
    user = fetch_user(payload['sub'])
    return render_token_error if user.nil?

    render json: { sub: payload['sub'], email: user['email'], name: user['name'] }
  rescue Auth::TokenService::InvalidTokenError
    render_token_error
  end

  private

  def bearer_token
    auth = request.headers['Authorization']
    return nil unless auth&.start_with?('Bearer ')

    auth.sub('Bearer ', '')
  end

  def fetch_user(user_id)
    response = HTTParty.get(
      "#{idp_user_url}/api/v1/users/#{user_id}",
      headers: { 'X-Internal-API-Key' => internal_api_key, 'Accept' => 'application/json' },
      timeout: 5
    )
    response.success? ? response.parsed_response : nil
  rescue HTTParty::Error, Timeout::Error, SocketError, Errno::ECONNREFUSED
    nil
  end

  def render_token_error
    render json: { error: 'invalid_token' }, status: :unauthorized
  end

  def idp_user_url
    ENV.fetch('IDP_USER_URL', 'http://idp-user:3001')
  end

  def internal_api_key
    ENV.fetch('INTERNAL_API_KEY')
  end
end
