require 'httparty'

module Auth
  class ClientAuthenticationService
    # idp-client の POST /api/v1/clients/verify で client authentication を行う。
    # 検証成功時はクライアント情報（Hash）、失敗時は nil を返す。
    def self.call(client_id:, client_secret:, redirect_uri: nil)
      response = HTTParty.post(verify_url, request_options(client_id, client_secret, redirect_uri))
      return nil unless response.success?

      response.parsed_response
    end

    def self.verify_url
      "#{ENV.fetch('IDP_CLIENT_URL')}/api/v1/clients/verify"
    end

    def self.request_options(client_id, client_secret, redirect_uri)
      {
        headers: headers,
        body: body(client_id, client_secret, redirect_uri)
      }
    end

    def self.headers
      {
        'X-Internal-API-Key' => ENV.fetch('INTERNAL_API_KEY'),
        'Content-Type' => 'application/json'
      }
    end

    def self.body(client_id, client_secret, redirect_uri)
      {
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: redirect_uri
      }.to_json
    end
  end
end
