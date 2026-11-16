module Auth
  class RefreshTokenService
    class InvalidScopeError < StandardError; end

    # リフレッシュトークンを検証・消費し、回転した新しい RefreshToken レコードを返す。
    # 検証失敗時は nil を返し、呼び出し元で invalid_grant に変換する。
    #
    # 同一トークンへの同時リクエストで両方が検証を通過しないよう、
    # 行ロック（SELECT ... FOR UPDATE）を取ったトランザクション内で検証・失効・発行を行う。
    # 再利用検知の失効を確実にコミットするため、ブロック内では return しない。
    def self.consume(token:, client_id:, scope: nil)
      RefreshToken.transaction do
        record = find_valid_record(token: token, client_id: client_id)
        rotate!(record, scope) if record
      end
    end

    def self.rotate!(record, scope)
      new_scope = resolve_scope(record, scope)
      record.revoke!
      RefreshToken.generate_for(
        user_id: record.user_id,
        client_id: record.client_id,
        scope: new_scope
      )
    end

    def self.find_valid_record(token:, client_id:)
      record = RefreshToken.lock.find_by(token: token)
      return nil if record.nil? || record.client_id != client_id

      if record.revoked?
        revoke_family!(record)
        return nil
      end
      return nil if record.expired?

      record
    end

    # 要求スコープは元の付与スコープの部分集合でなければならない（RFC 6749 §6）
    def self.resolve_scope(record, requested_scope)
      return record.scope if requested_scope.blank?

      granted = Oidc::Scopes.parse(record.scope)
      requested = Oidc::Scopes.parse(requested_scope)
      raise InvalidScopeError if (requested - granted).any?

      Oidc::Scopes.join(requested)
    end

    # 失効済みトークンの再提示は漏洩の兆候とみなし、
    # 同一 user / client の有効なリフレッシュトークンを全て失効させる
    def self.revoke_family!(record)
      RefreshToken.where(user_id: record.user_id, client_id: record.client_id, revoked_at: nil)
                  .find_each(&:revoke!)
    end
  end
end
