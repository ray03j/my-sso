module Oidc
  module Scopes
    OPENID = 'openid'.freeze
    PROFILE = 'profile'.freeze
    EMAIL = 'email'.freeze

    SUPPORTED = [OPENID, PROFILE, EMAIL].freeze

    def self.valid?(scope_string)
      requested = parse(scope_string)
      requested.all? { |scope| SUPPORTED.include?(scope) }
    end

    def self.parse(scope_string)
      scope_string.to_s.split.map(&:strip).compact_blank.uniq
    end

    def self.join(scopes)
      Array(scopes).map(&:to_s).map(&:strip).compact_blank.uniq.join(' ')
    end
  end
end
