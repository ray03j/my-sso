class AccessToken < ApplicationRecord
  validates :token, presence: true, uniqueness: true
  validates :user_id, presence: true
  validates :client_id, presence: true
  validates :expires_at, presence: true
end
