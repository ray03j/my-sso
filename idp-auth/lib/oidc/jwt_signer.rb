require 'jwt'

module Oidc
  module JwtSigner
    ALGORITHM = 'HS256'.freeze
    SECRET = ENV.fetch('JWT_SECRET')

    def self.sign(payload)
      JWT.encode(payload, SECRET, ALGORITHM)
    end

    def self.verify(token)
      JWT.decode(token, SECRET, true, { algorithm: ALGORITHM })
    end
  end
end
