class User < ApplicationRecord
  validates :email, presence: true, uniqueness: true
  validates :password_hash, presence: true
end
