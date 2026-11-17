# id_token / access_token の署名検証に使う公開鍵を JWK Set で配信する（RFC 7517）。
# Discovery の jwks_uri から辿られる。公開鍵だけを出力し、秘密鍵の成分は含めない
class JwksController < ApplicationController
  # RP は JWKS をキャッシュし、知らない kid が来たときだけ取り直す。
  # 長すぎると鍵ローテーション時に新しい鍵が行き渡るまで時間がかかるため 1 時間にする
  CACHE_MAX_AGE = 1.hour

  def show
    expires_in CACHE_MAX_AGE, public: true
    render json: Oidc::JwtSigner.jwks.export
  end
end
