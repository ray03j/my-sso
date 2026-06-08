class Consent < ApplicationRecord
  validates :user_id, presence: true, uniqueness: { scope: :client_id }
  validates :client_id, presence: true
  validates :scope, presence: true
end
