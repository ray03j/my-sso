require 'httparty'

class AuthorizeController < ApplicationController
  class AuthorizeError < StandardError; end

  REQUIRED_PARAMS = %w[
    client_id redirect_uri response_type scope state
    code_challenge code_challenge_method
  ].freeze

  def show
    client = fetch_client(params[:client_id], params[:redirect_uri], params[:scope])
    return render plain: 'invalid_client', status: :bad_request if client.nil?

    validate_required_params!
    validate_response_type!
    validate_code_challenge_method!

    unless authenticated?
      store_authorize_params!
      return redirect_to login_url
    end

    unless consent_recorded?(client['client_id'], params[:scope])
      store_authorize_params!
      return redirect_to consent_url
    end

    code = issue_authorization_code(client)
    redirect_to redirect_uri_with_code(code), allow_other_host: true
  rescue AuthorizeError => e
    redirect_with_error(e.message)
  end

  private

  def validate_required_params!
    missing = REQUIRED_PARAMS.select { |p| params[p].blank? }
    raise AuthorizeError, 'invalid_request' if missing.any?
  end

  def validate_response_type!
    raise AuthorizeError, 'unsupported_response_type' unless params[:response_type] == 'code'
  end

  def validate_code_challenge_method!
    raise AuthorizeError, 'invalid_request' unless params[:code_challenge_method] == 'S256'
  end

  def fetch_client(client_id, redirect_uri, scope)
    response = HTTParty.get(
      "#{idp_client_url}/api/v1/clients/#{client_id}",
      headers: {
        'X-Internal-API-Key' => internal_api_key,
        'Accept' => 'application/json'
      }
    )
    return nil unless response.success?

    client = response.parsed_response
    return nil unless client['redirect_uris'].include?(redirect_uri)
    return nil unless requested_scopes(scope).all? { |s| client['allowed_scopes'].include?(s) }

    client
  end

  def requested_scopes(scope)
    scope.to_s.split.map(&:strip).compact_blank
  end

  def issue_authorization_code(client)
    Auth::AuthorizationCodeService.issue(
      user_id: current_session_user_id,
      client_id: client['client_id'],
      redirect_uri: params[:redirect_uri],
      scope: params[:scope],
      code_challenge: params[:code_challenge],
      code_challenge_method: params[:code_challenge_method]
    ).code
  end

  def consent_recorded?(client_id, scope)
    Consent.exists?(
      user_id: current_session_user_id,
      client_id: client_id,
      scope: scope
    )
  end

  def store_authorize_params!
    session[:authorize_params] = params.permit(
      :client_id, :redirect_uri, :response_type, :scope, :state,
      :code_challenge, :code_challenge_method, :nonce
    ).to_h
  end

  def redirect_uri_with_code(code)
    build_redirect_uri(params[:redirect_uri], code: code)
  end

  def redirect_with_error(error)
    return render plain: error, status: :bad_request if params[:redirect_uri].blank?

    redirect_to build_redirect_uri(params[:redirect_uri], error: error), allow_other_host: true
  end

  def build_redirect_uri(redirect_uri, error: nil, code: nil)
    uri = URI.parse(redirect_uri)
    query = Rack::Utils.parse_query(uri.query)
    query = query.merge('error' => error) if error.present?
    query = query.merge('code' => code) if code.present?
    query = query.merge('state' => params[:state]) if params[:state].present?
    uri.query = Rack::Utils.build_nested_query(query)
    uri.to_s
  end

  def login_url
    '/login'
  end

  def consent_url
    '/consent'
  end

  def idp_client_url
    ENV.fetch('IDP_CLIENT_URL')
  end

  def internal_api_key
    ENV.fetch('INTERNAL_API_KEY')
  end
end
