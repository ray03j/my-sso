module Oidc
  module Scopes
    OPENID = 'openid'.freeze
    PROFILE = 'profile'.freeze
    EMAIL = 'email'.freeze

    SUPPORTED = [OPENID, PROFILE, EMAIL].freeze

    # スコープごとに UserInfo で返すクレーム（OIDC Core §5.4）。
    # idp-user が保持している属性のみ対応する（email_verified などは未保持のため返さない）
    CLAIMS = {
      PROFILE => %w[name],
      EMAIL => %w[email]
    }.freeze

    def self.valid?(scope_string)
      requested = parse(scope_string)
      requested.all? { |scope| SUPPORTED.include?(scope) }
    end

    def self.parse(scope_string)
      scope_string.to_s.split.map(&:strip).compact_blank.uniq
    end

    def self.claims_for(scope_string)
      parse(scope_string).flat_map { |scope| CLAIMS.fetch(scope, []) }
    end

    def self.join(scopes)
      Array(scopes).map(&:to_s).map(&:strip).compact_blank.uniq.join(' ')
    end
  end
end
