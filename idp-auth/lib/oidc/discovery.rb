module Oidc
  module Discovery
    ISSUER = ENV.fetch('OIDC_ISSUER', 'http://localhost:3000').freeze

    def self.metadata
      {
        issuer: ISSUER,
        **endpoints,
        **supported_config
      }
    end

    def self.endpoints
      {
        authorization_endpoint: "#{ISSUER}/authorize",
        token_endpoint: "#{ISSUER}/token",
        userinfo_endpoint: "#{ISSUER}/userinfo",
        jwks_uri: "#{ISSUER}/jwks.json"
      }
    end

    def self.supported_config
      {
        response_types_supported: ['code'],
        grant_types_supported: GrantTypes::SUPPORTED,
        scopes_supported: Scopes::SUPPORTED,
        token_endpoint_auth_methods_supported: %w[client_secret_post client_secret_basic],
        claims_supported: %w[sub name email],
        id_token_signing_alg_values_supported: ['HS256'],
        code_challenge_methods_supported: ['S256']
      }
    end
  end
end
