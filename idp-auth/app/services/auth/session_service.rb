require 'httparty'

module Auth
  class SessionService
    def self.authenticate(email, password)
      response = HTTParty.post(idp_user_verify_url, request_options(email, password))
      return nil unless response.success?

      response.parsed_response['user']
    rescue Net::OpenTimeout, Net::ReadTimeout
      nil
    end

    def self.request_options(email, password)
      {
        headers: {
          'Content-Type' => 'application/json',
          'X-Internal-API-Key' => internal_api_key
        },
        body: { email: email, password: password }.to_json,
        timeout: 5
      }
    end

    def self.idp_user_verify_url
      ENV.fetch('IDP_USER_VERIFY_URL', 'http://idp-user:3001/api/v1/auth/verify')
    end

    def self.internal_api_key
      ENV.fetch('INTERNAL_API_KEY')
    end
  end
end
