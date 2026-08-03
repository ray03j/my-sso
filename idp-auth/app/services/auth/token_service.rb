module Auth
  class TokenService
    class InvalidTokenError < StandardError; end

    def self.issue_access_token(user_id:, client_id:, scope: 'openid')
      payload = build_payload(user_id: user_id, client_id: client_id, scope: scope)
      token = Oidc::JwtSigner.sign(payload)
      persist_access_token(token, payload)
      token
    end

    def self.verify_access_token(token)
      Oidc::JwtSigner.verify(token).first
    rescue JWT::DecodeError => e
      raise InvalidTokenError, e.message
    end

    def self.issue_refresh_token(user_id:, client_id:, scope: 'openid')
      RefreshToken.generate_for(
        user_id: user_id,
        client_id: client_id,
        scope: scope
      ).token
    end

    def self.build_payload(user_id:, client_id:, scope:)
      {
        sub: user_id,
        client_id: client_id,
        scope: scope,
        iat: Time.current.to_i,
        exp: AccessToken::EXPIRES_IN.seconds.from_now.to_i,
        jti: SecureRandom.uuid
      }
    end

    def self.persist_access_token(token, payload)
      AccessToken.create!(
        token: token,
        user_id: payload[:sub],
        client_id: payload[:client_id],
        scope: payload[:scope],
        expires_at: Time.zone.at(payload[:exp])
      )
    end
  end
end
