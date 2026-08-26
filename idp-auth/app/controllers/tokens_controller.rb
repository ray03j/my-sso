require 'httparty'

class TokensController < ApplicationController
  ID_TOKEN_EXPIRES_IN = 3600 # 1時間

  REQUIRED_PARAMS = %w[
    grant_type code redirect_uri code_verifier client_id client_secret
  ].freeze

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def create
    return unless validate_required_params!
    return unless validate_grant_type!

    client = authenticate_client(params[:client_id], params[:client_secret], params[:redirect_uri])
    return render_token_error('invalid_client', :unauthorized) unless client

    code_record = Auth::AuthorizationCodeService.consume(
      code: params[:code],
      client_id: params[:client_id],
      redirect_uri: params[:redirect_uri]
    )
    return render_token_error('invalid_grant', :bad_request) unless code_record

    unless Auth::AuthorizationCodeService.verify_pkce(
      record: code_record,
      code_verifier: params[:code_verifier]
    )
      return render_token_error('invalid_grant', :bad_request)
    end

    access_token = Auth::TokenService.issue_access_token(
      user_id: code_record.user_id,
      client_id: code_record.client_id,
      scope: code_record.scope
    )
    id_token = issue_id_token(code_record, client, params[:nonce], access_token)
    refresh_token = Auth::TokenService.issue_refresh_token(
      user_id: code_record.user_id,
      client_id: code_record.client_id,
      scope: code_record.scope
    )

    render json: {
      access_token: access_token,
      id_token: id_token,
      refresh_token: refresh_token,
      token_type: 'Bearer',
      expires_in: AccessToken::EXPIRES_IN
    }
  rescue Auth::TokenService::InvalidTokenError
    render_token_error('server_error', :internal_server_error)
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  private

  # rubocop:disable Naming/PredicateMethod
  def validate_required_params!
    missing = REQUIRED_PARAMS - params.keys
    return true if missing.empty?

    render_token_error('invalid_request', :bad_request)
    false
  end

  def validate_grant_type!
    return true if params[:grant_type] == 'authorization_code'

    render_token_error('unsupported_grant_type', :bad_request)
    false
  end
  # rubocop:enable Naming/PredicateMethod

  # rubocop:disable Metrics/MethodLength
  def authenticate_client(client_id, client_secret, redirect_uri)
    response = HTTParty.post(
      "#{idp_client_url}/api/v1/clients/verify",
      headers: {
        'X-Internal-API-Key' => internal_api_key,
        'Content-Type' => 'application/json'
      },
      body: {
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: redirect_uri
      }.to_json
    )
    return nil unless response.success?

    response.parsed_response
  end
  # rubocop:enable Metrics/MethodLength

  def issue_id_token(code_record, client, nonce, access_token)
    payload = {
      iss: Oidc::Discovery::ISSUER,
      sub: code_record.user_id,
      aud: client['client_id'],
      exp: ID_TOKEN_EXPIRES_IN.seconds.from_now.to_i,
      iat: Time.current.to_i,
      nonce: nonce,
      at_hash: at_hash(access_token)
    }.compact

    Oidc::JwtSigner.sign(payload)
  end

  def at_hash(access_token)
    return nil if access_token.blank?

    Base64.urlsafe_encode64(
      Digest::SHA256.digest(access_token)[0, 16],
      padding: false
    )
  end

  def render_token_error(error, status)
    render json: { error: error }, status: status
  end

  def idp_client_url
    ENV.fetch('IDP_CLIENT_URL')
  end

  def internal_api_key
    ENV.fetch('INTERNAL_API_KEY')
  end
end
