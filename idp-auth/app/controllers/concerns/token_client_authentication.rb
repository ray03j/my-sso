# /token のクライアント認証情報を Auth::ClientCredentials で取り出し、失敗時は OAuth のエラーを返す。
# 取り出した認証情報は @client_credentials に入れる。
module TokenClientAuthentication
  extend ActiveSupport::Concern

  private

  def extract_client_credentials!
    @client_credentials = Auth::ClientCredentials.from(authorization: request.authorization, params: params)
    true
  rescue Auth::ClientCredentials::InvalidRequestError
    render json: { error: 'invalid_request' }, status: :bad_request
    false
  rescue Auth::ClientCredentials::InvalidClientError
    render_invalid_client(basic: true)
    false
  end

  # Authorization ヘッダで認証を試みたクライアントには、同じ方式の WWW-Authenticate を返す（RFC 6749 §5.2）
  def render_invalid_client(basic:)
    response.headers['WWW-Authenticate'] = %(Basic realm="#{Oidc::Discovery::ISSUER}") if basic
    render json: { error: 'invalid_client' }, status: :unauthorized
  end
end
