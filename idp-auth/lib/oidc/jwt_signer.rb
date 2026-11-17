require 'jwt'

module Oidc
  # access_token / id_token を RS256 で署名・検証する（OIDC Core §15.1）。
  # 署名鍵は環境変数 JWT_PRIVATE_KEY（PEM）から読み込み、公開鍵だけを JWKS として配信する。
  module JwtSigner
    ALGORITHM = 'RS256'.freeze

    # ヘッダの kid に JWK Thumbprint（RFC 7638）を入れ、検証者が JWKS から鍵を選べるようにする
    def self.sign(payload)
      JWT.encode(payload, signing_jwk.signing_key, ALGORITHM, { kid: signing_jwk[:kid] })
    end

    # ヘッダの alg を信用せず RS256 に固定する。公開鍵を HS256 の共通鍵として使わせる
    # アルゴリズム混同攻撃や alg=none を拒否するため（RFC 8725 §3.1）
    def self.verify(token)
      JWT.decode(token, nil, true, { algorithms: [ALGORITHM], jwks: jwks })
    end

    # /jwks.json で公開する JWK Set。鍵ローテーション時に複数の鍵を並べられるよう Set で返す
    def self.jwks
      JWT::JWK::Set.new([signing_jwk])
    end

    def self.signing_jwk
      @signing_jwk ||= JWT::JWK.new(private_key, { use: 'sig', alg: ALGORITHM }, kid_generator: JWT::JWK::Thumbprint)
    end

    # .env では改行を "\n" と書けるよう、エスケープされた改行を戻してから読み込む。
    # 本番で未設定なら起動を失敗させ、開発・テストではプロセスごとに鍵を生成する
    def self.private_key
      pem = ENV.fetch('JWT_PRIVATE_KEY', '')
      return OpenSSL::PKey::RSA.new(pem.gsub('\n', "\n")) if pem.present?
      raise KeyError, 'JWT_PRIVATE_KEY is not set' if Rails.env.production?

      Rails.logger.warn('JWT_PRIVATE_KEY is not set; generating an ephemeral RSA key')
      OpenSSL::PKey::RSA.generate(2048)
    end

    private_class_method :signing_jwk, :private_key
  end
end
