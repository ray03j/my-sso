class Client < ApplicationRecord
  validates :client_id, presence: true, uniqueness: true
  validates :client_secret_hash, presence: true
  validates :name, presence: true
  validates :redirect_uris, presence: true
  validates :allowed_scopes, presence: true
end
