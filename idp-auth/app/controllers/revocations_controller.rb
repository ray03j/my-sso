# クライアントが不要になったトークンを失効させる（RFC 7009）
class RevocationsController < ApplicationController
  # /token と同じく client_secret_basic / client_secret_post でクライアント認証する（§2.1）
  include TokenClientAuthentication

  def create
    return unless extract_client_credentials! && authenticate_client!
    return render json: { error: 'invalid_request' }, status: :bad_request if params[:token].blank?

    Auth::TokenRevocationService.revoke(
      token: params[:token],
      client_id: @client_credentials.client_id,
      token_type_hint: params[:token_type_hint]
    )
    # 失効させた場合も、無効なトークンだった場合も 200 を返す（§2.2）
    head :ok
  end

  private

  # rubocop:disable Naming/PredicateMethod
  def authenticate_client!
    client = Auth::ClientAuthenticationService.call(
      client_id: @client_credentials.client_id,
      client_secret: @client_credentials.client_secret
    )
    return true if client

    render_invalid_client(basic: @client_credentials.basic?)
    false
  end
  # rubocop:enable Naming/PredicateMethod
end
