class AuthorizationCode < ApplicationRecord
  EXPIRES_IN = 600 # 10分

  validates :code, presence: true, uniqueness: true
  validates :user_id, presence: true
  validates :client_id, presence: true
  validates :redirect_uri, presence: true
  validates :expires_at, presence: true

  def expired?
    expires_at < Time.current
  end

  def used?
    used
  end

  def self.generate_for(user_id:, client_id:, redirect_uri:, scope: 'openid',
                        code_challenge: nil, code_challenge_method: nil)
    create!(
      code: SecureRandom.urlsafe_base64(32),
      user_id: user_id,
      client_id: client_id,
      redirect_uri: redirect_uri,
      scope: scope,
      code_challenge: code_challenge,
      code_challenge_method: code_challenge_method,
      expires_at: EXPIRES_IN.seconds.from_now
    )
  end
end
