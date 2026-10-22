class TokensController < ApplicationController
  GRANT_REQUIRED_PARAMS = {
    'authorization_code' => %w[grant_type code redirect_uri code_verifier client_id client_secret],
    'refresh_token' => %w[grant_type refresh_token client_id client_secret]
  }.freeze

  def create
    return unless validate_required_params! && validate_grant_type!

    if refresh_token_grant?
      create_with_refresh_token_grant
    else
      create_with_authorization_code_grant
    end
  rescue Auth::TokenService::InvalidTokenError
    render_token_error('server_error', :internal_server_error)
  rescue Auth::RefreshTokenService::InvalidScopeError
    render_token_error('invalid_scope', :bad_request)
  end

  private

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def create_with_authorization_code_grant
    client = Auth::ClientAuthenticationService.call(
      client_id: params[:client_id],
      client_secret: params[:client_secret],
      redirect_uri: params[:redirect_uri]
    )
    return render_token_error('invalid_client', :unauthorized) unless client

    code_record = Auth::AuthorizationCodeService.consume(
      code: params[:code],
      client_id: params[:client_id],
      redirect_uri: params[:redirect_uri],
      code_verifier: params[:code_verifier]
    )
    return render_token_error('invalid_grant', :bad_request) unless code_record

    access_token = Auth::TokenService.issue_access_token(
      user_id: code_record.user_id,
      client_id: code_record.client_id,
      scope: code_record.scope
    )
    id_token = Auth::TokenService.issue_id_token(
      user_id: code_record.user_id,
      client_id: client['client_id'],
      nonce: params[:nonce],
      access_token: access_token
    )
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
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def create_with_refresh_token_grant
    client = Auth::ClientAuthenticationService.call(
      client_id: params[:client_id],
      client_secret: params[:client_secret]
    )
    return render_token_error('invalid_client', :unauthorized) unless client

    new_refresh_token = Auth::RefreshTokenService.consume(
      token: params[:refresh_token],
      client_id: params[:client_id],
      scope: params[:scope]
    )
    return render_token_error('invalid_grant', :bad_request) if new_refresh_token.nil?

    access_token = Auth::TokenService.issue_access_token(
      user_id: new_refresh_token.user_id,
      client_id: new_refresh_token.client_id,
      scope: new_refresh_token.scope
    )
    render json: {
      access_token: access_token,
      refresh_token: new_refresh_token.token,
      token_type: 'Bearer',
      expires_in: AccessToken::EXPIRES_IN,
      scope: new_refresh_token.scope
    }
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def refresh_token_grant?
    params[:grant_type] == Oidc::GrantTypes::REFRESH_TOKEN
  end

  # rubocop:disable Naming/PredicateMethod
  def validate_required_params!
    required = GRANT_REQUIRED_PARAMS.fetch(params[:grant_type], %w[grant_type])
    missing = required - params.keys
    return true if missing.empty?

    render_token_error('invalid_request', :bad_request)
    false
  end

  def validate_grant_type!
    return true if Oidc::GrantTypes.valid?(params[:grant_type])

    render_token_error('unsupported_grant_type', :bad_request)
    false
  end
  # rubocop:enable Naming/PredicateMethod

  def render_token_error(error, status)
    render json: { error: error }, status: status
  end
end
