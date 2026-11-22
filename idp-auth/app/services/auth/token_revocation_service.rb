module Auth
  # トークンを失効させる（RFC 7009）
  class TokenRevocationService
    TOKEN_TYPE_HINTS = %w[access_token refresh_token].freeze

    # 他のクライアントのトークンや存在しないトークンでは何もしない。
    # どちらの場合も呼び出し元は 200 を返し、トークンの存在を漏らさない（§2.2）
    def self.revoke(token:, client_id:, token_type_hint: nil)
      record = find_record(token, token_type_hint)
      return if record.nil? || record.client_id != client_id

      record.is_a?(RefreshToken) ? revoke_refresh_token(record) : record.revoke!
    end

    # token_type_hint は検索の順番を決めるだけで、違う種類のトークンでも探す（§2.1）
    def self.find_record(token, token_type_hint)
      models = token_type_hint == 'access_token' ? [AccessToken, RefreshToken] : [RefreshToken, AccessToken]
      models.lazy.filter_map { |model| model.find_by(token: token) }.first
    end

    # refresh_token を失効させたら、同じ認可で発行した access_token も失効させる（§2.1）。
    # 認可ごとの紐付けを持たないため、同じユーザー・クライアントの access_token を対象にする
    def self.revoke_refresh_token(record)
      RefreshToken.transaction do
        record.revoke! unless record.revoked?
        AccessToken.where(user_id: record.user_id, client_id: record.client_id, revoked_at: nil)
                   .find_each(&:revoke!)
      end
    end

    private_class_method :find_record, :revoke_refresh_token
  end
end
