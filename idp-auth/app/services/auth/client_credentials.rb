module Auth
  # /token のリクエストからクライアント認証情報を取り出す。
  # client_secret_basic（Authorization: Basic）と client_secret_post（リクエストボディ）に対応する（OIDC Core §9）。
  class ClientCredentials
    # 認証方式の重複やパラメータ欠落など、リクエストの形式が不正（error=invalid_request）
    class InvalidRequestError < StandardError; end
    # Authorization: Basic ヘッダの値を解釈できない（error=invalid_client）
    class InvalidClientError < StandardError; end

    BASIC_SCHEME = 'Basic'.freeze

    attr_reader :client_id, :client_secret, :auth_method

    def self.from(authorization:, params:)
      if authorization.to_s.start_with?("#{BASIC_SCHEME} ")
        from_basic(authorization, params)
      else
        from_post(params)
      end
    end

    def self.from_basic(authorization, params)
      # 1 つのリクエストで複数の認証方式を使ってはならない（RFC 6749 §2.3）
      raise InvalidRequestError if params[:client_secret].present?

      client_id, client_secret = decode_basic(authorization.delete_prefix("#{BASIC_SCHEME} ").strip)
      # ボディにも client_id がある場合は、ヘッダと一致しなければならない
      raise InvalidRequestError if params[:client_id].present? && params[:client_id] != client_id

      new(client_id, client_secret, :client_secret_basic)
    end

    def self.from_post(params)
      raise InvalidRequestError if params[:client_id].blank? || params[:client_secret].blank?

      new(params[:client_id], params[:client_secret], :client_secret_post)
    end

    # client_id と client_secret は application/x-www-form-urlencoded でエンコードしてから
    # ":" でつなぎ、Base64 にする（RFC 6749 §2.3.1）
    def self.decode_basic(encoded)
      client_id, client_secret = Base64.strict_decode64(encoded).split(':', 2)
      raise InvalidClientError if client_id.blank? || client_secret.blank?

      [CGI.unescape(client_id), CGI.unescape(client_secret)]
    rescue ArgumentError
      raise InvalidClientError
    end

    private_class_method :from_basic, :from_post, :decode_basic

    def initialize(client_id, client_secret, auth_method)
      @client_id = client_id
      @client_secret = client_secret
      @auth_method = auth_method
    end

    def basic?
      auth_method == :client_secret_basic
    end
  end
end
