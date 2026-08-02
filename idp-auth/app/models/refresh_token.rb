class RefreshToken < ApplicationRecord
  validates :token, presence: true, uniqueness: true
  validates :user_id, presence: true
  validates :client_id, presence: true

  def self.generate_for(user_id:, client_id:, scope: 'openid')
    create!(
      token: SecureRandom.urlsafe_base64(32),
      user_id: user_id,
      client_id: client_id,
      scope: scope
    )
  end
end
