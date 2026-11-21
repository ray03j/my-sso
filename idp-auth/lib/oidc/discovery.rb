module Oidc
  module Discovery
    ISSUER = ENV.fetch('OIDC_ISSUER', 'http://localhost:3000').freeze
    CLIENT_AUTH_METHODS = %w[client_secret_post client_secret_basic].freeze

    def self.metadata
      {
        issuer: ISSUER,
        **endpoints,
        **supported_config,
        # /revoke も /token と同じ方式でクライアント認証する（RFC 8414 §2）
        revocation_endpoint_auth_methods_supported: CLIENT_AUTH_METHODS
      }
    end

    def self.endpoints
      {
        authorization_endpoint: "#{ISSUER}/authorize",
        token_endpoint: "#{ISSUER}/token",
        userinfo_endpoint: "#{ISSUER}/userinfo",
        jwks_uri: "#{ISSUER}/jwks.json",
        revocation_endpoint: "#{ISSUER}/revoke"
      }
    end

    def self.supported_config
      {
        response_types_supported: ['code'],
        # 全 RP に同じ User UUID を sub として返すため public のみ（OIDC Core §8）
        subject_types_supported: ['public'],
        grant_types_supported: GrantTypes::SUPPORTED,
        scopes_supported: Scopes::SUPPORTED,
        token_endpoint_auth_methods_supported: CLIENT_AUTH_METHODS,
        claims_supported: %w[sub name email],
        # RS256 は必須（OIDC Core §15.1, Discovery 1.0 §3）。署名に使うアルゴリズムと一致させる
        id_token_signing_alg_values_supported: [JwtSigner::ALGORITHM],
        code_challenge_methods_supported: ['S256']
      }
    end
  end
end
