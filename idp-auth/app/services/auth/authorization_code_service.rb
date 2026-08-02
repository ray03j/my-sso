module Auth
  class AuthorizationCodeService
    class InvalidRequestError < StandardError; end

    def self.issue(user_id:, client_id:, redirect_uri:, scope: 'openid')
      validate_params!(user_id: user_id, client_id: client_id, redirect_uri: redirect_uri)

      AuthorizationCode.generate_for(
        user_id: user_id,
        client_id: client_id,
        redirect_uri: redirect_uri,
        scope: scope
      )
    end

    def self.verify(code:, client_id:, redirect_uri:)
      record = AuthorizationCode.find_by(code: code)
      return nil if record.nil? || record.expired? || record.used?
      return nil unless record.client_id == client_id
      return nil unless record.redirect_uri == redirect_uri

      record
    end

    def self.consume(code:, client_id:, redirect_uri:)
      record = verify(code: code, client_id: client_id, redirect_uri: redirect_uri)
      return nil if record.nil?

      record.update!(used: true)
      record
    end

    def self.validate_params!(user_id:, client_id:, redirect_uri:)
      raise InvalidRequestError, 'user_id is required' if user_id.blank?
      raise InvalidRequestError, 'client_id is required' if client_id.blank?
      raise InvalidRequestError, 'redirect_uri is required' if redirect_uri.blank?
    end
  end
end
