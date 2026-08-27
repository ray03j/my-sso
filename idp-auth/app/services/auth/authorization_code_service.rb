module Auth
  class AuthorizationCodeService
    class InvalidRequestError < StandardError; end

    def self.issue(user_id:, client_id:, redirect_uri:, scope: 'openid', code_challenge:, code_challenge_method:)
      validate_params!(user_id: user_id, client_id: client_id, redirect_uri: redirect_uri)
      validate_pkce!(code_challenge: code_challenge, code_challenge_method: code_challenge_method)

      AuthorizationCode.generate_for(
        user_id: user_id,
        client_id: client_id,
        redirect_uri: redirect_uri,
        scope: scope,
        code_challenge: code_challenge,
        code_challenge_method: code_challenge_method
      )
    end

    def self.verify_pkce(record:, code_verifier:)
      return false if record.code_challenge.blank?
      return false if record.code_challenge_method != 'S256'
      return false if code_verifier.blank?

      calculated = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
      ActiveSupport::SecurityUtils.fixed_length_secure_compare(calculated, record.code_challenge)
    end

    def self.verify(code:, client_id:, redirect_uri:)
      record = AuthorizationCode.find_by(code: code)
      return nil if record.nil? || record.expired? || record.used?
      return nil unless record.client_id == client_id
      return nil unless record.redirect_uri == redirect_uri

      record
    end

    def self.consume(code:, client_id:, redirect_uri:, code_verifier:)
      record = verify(code: code, client_id: client_id, redirect_uri: redirect_uri)
      return nil if record.nil?

      return nil unless verify_pkce(record: record, code_verifier: code_verifier)

      record.update!(used: true)
      record
    end

    def self.validate_params!(user_id:, client_id:, redirect_uri:)
      raise InvalidRequestError, 'user_id is required' if user_id.blank?
      raise InvalidRequestError, 'client_id is required' if client_id.blank?
      raise InvalidRequestError, 'redirect_uri is required' if redirect_uri.blank?
    end

    def self.validate_pkce!(code_challenge:, code_challenge_method:)
      raise InvalidRequestError, 'code_challenge is required' if code_challenge.blank?
      raise InvalidRequestError, 'unsupported code_challenge_method' unless code_challenge_method == 'S256'
    end
  end
end
