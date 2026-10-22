class AuthorizeController < ApplicationController
  class AuthorizeError < StandardError; end

  REQUIRED_PARAMS = %w[
    client_id redirect_uri response_type scope state
    code_challenge code_challenge_method
  ].freeze

  def show
    client = fetch_client
    return render plain: 'invalid_client', status: :bad_request if client.nil?

    validate_authorize_request!
    return continue_at(login_url) unless authenticated?
    return continue_at(consent_url) unless consent_recorded?(client)

    redirect_to redirect_uri_with_code(issue_authorization_code(client)), allow_other_host: true
  rescue AuthorizeError => e
    redirect_with_error(e.message)
  end

  private

  def fetch_client
    Auth::ClientRegistryService.fetch(
      client_id: params[:client_id],
      redirect_uri: params[:redirect_uri],
      scope: params[:scope]
    )
  end

  def validate_authorize_request!
    validate_required_params!
    validate_response_type!
    validate_code_challenge_method!
  end

  def continue_at(url)
    store_authorize_params!
    redirect_to url
  end

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

  def consent_recorded?(client)
    Consent.exists?(
      user_id: current_session_user_id,
      client_id: client['client_id'],
      scope: Consent.normalize_scope(params[:scope])
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
    extras = { 'error' => error, 'code' => code, 'state' => params[:state] }.compact_blank
    uri.query = Rack::Utils.build_nested_query(query.merge(extras))
    uri.to_s
  end

  def login_url
    '/login'
  end

  def consent_url
    '/consent'
  end
end
