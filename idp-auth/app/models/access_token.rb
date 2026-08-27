class AccessToken < ApplicationRecord
  EXPIRES_IN = 900 # 15分

  validates :token, presence: true, uniqueness: true
  validates :user_id, presence: true
  validates :client_id, presence: true
  validates :expires_at, presence: true

  def expired?
    expires_at < Time.current
  end

  def self.generate_for(user_id:, client_id:, scope: 'openid')
    create!(
      token: SecureRandom.urlsafe_base64(32),
      user_id: user_id,
      client_id: client_id,
      scope: scope,
      expires_at: EXPIRES_IN.seconds.from_now
    )
  end
end
