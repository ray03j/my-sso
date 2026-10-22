require 'httparty'

module Auth
  class ClientRegistryService
    # idp-client の GET /api/v1/clients/:client_id でクライアント登録情報を取得する。
    # redirect_uri と scope が登録内容に許可されている場合のみクライアント情報（Hash）を返し、
    # 取得失敗・不一致の場合は nil を返す。
    def self.fetch(client_id:, redirect_uri:, scope:)
      response = HTTParty.get(client_url(client_id), headers: headers)
      return nil unless response.success?

      client = response.parsed_response
      return nil unless permitted_redirect_uri?(client, redirect_uri)
      return nil unless permitted_scope?(client, scope)

      client
    end

    def self.client_url(client_id)
      "#{ENV.fetch('IDP_CLIENT_URL')}/api/v1/clients/#{client_id}"
    end

    def self.headers
      {
        'X-Internal-API-Key' => ENV.fetch('INTERNAL_API_KEY'),
        'Accept' => 'application/json'
      }
    end

    def self.permitted_redirect_uri?(client, redirect_uri)
      client['redirect_uris'].include?(redirect_uri)
    end

    def self.permitted_scope?(client, scope)
      requested_scopes(scope).all? { |s| client['allowed_scopes'].include?(s) }
    end

    def self.requested_scopes(scope)
      scope.to_s.split.map(&:strip).compact_blank
    end
  end
end
