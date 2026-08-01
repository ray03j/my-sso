module Oidc
  module GrantTypes
    AUTHORIZATION_CODE = 'authorization_code'.freeze
    REFRESH_TOKEN = 'refresh_token'.freeze

    SUPPORTED = [AUTHORIZATION_CODE, REFRESH_TOKEN].freeze

    def self.valid?(grant_type)
      SUPPORTED.include?(grant_type.to_s)
    end
  end
end
