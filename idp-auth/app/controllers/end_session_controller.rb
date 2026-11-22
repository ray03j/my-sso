# RP からのログアウト要求を受け、IdP のセッションを終了する（OpenID Connect RP-Initiated Logout 1.0）
class EndSessionController < ApplicationController
  class EndSessionError < StandardError; end

  # RP-Initiated Logout では GET と POST の両方に対応しなければならない（§2）。
  # POST は RP のフォームから届き CSRF トークンを持ち得ないため、代わりに id_token_hint で要求元を確かめる
  skip_forgery_protection only: :show

  def show
    claims = verify_id_token_hint!
    client = fetch_client!(claims)
    redirect_uri = validate_post_logout_redirect_uri!(client)

    reset_session if current_session_user_id == claims['sub']

    return render plain: 'ログアウトしました。' if redirect_uri.nil?

    redirect_to with_state(redirect_uri), allow_other_host: true
  rescue EndSessionError => e
    render plain: e.message, status: :bad_request
  end

  private

  # 第三者のページから勝手にログアウトさせられないよう、IdP が発行した ID Token を必須にする。
  # 期限切れでも受け付ける（§2）
  def verify_id_token_hint!
    raise EndSessionError, 'invalid_request' if params[:id_token_hint].blank?

    claims, = Oidc::JwtSigner.verify(params[:id_token_hint], verify_expiration: false)
    raise EndSessionError, 'invalid_request' unless claims['iss'] == Oidc::Discovery::ISSUER

    claims
  rescue JWT::DecodeError
    raise EndSessionError, 'invalid_request'
  end

  # client_id を指定する場合は、id_token_hint の aud と一致しなければならない（§2）
  def fetch_client!(claims)
    client_id = Array(claims['aud']).first
    raise EndSessionError, 'invalid_request' if params[:client_id].present? && params[:client_id] != client_id

    client = Auth::ClientRegistryService.find(client_id)
    raise EndSessionError, 'invalid_client' if client.nil?

    client
  end

  # 戻り先は登録済みの値と完全に一致しなければならない（§3）
  def validate_post_logout_redirect_uri!(client)
    uri = params[:post_logout_redirect_uri]
    return nil if uri.blank?
    return uri if Array(client['post_logout_redirect_uris']).include?(uri)

    raise EndSessionError, 'invalid_request'
  end

  def with_state(redirect_uri)
    uri = URI.parse(redirect_uri)
    query = Rack::Utils.parse_query(uri.query).merge({ 'state' => params[:state] }.compact_blank)
    uri.query = query.empty? ? nil : Rack::Utils.build_query(query)
    uri.to_s
  end
end
