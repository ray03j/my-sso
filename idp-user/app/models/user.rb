class User < ApplicationRecord
  has_secure_password

  EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/
  PASSWORD_MIN_LENGTH = 8
  PASSWORD_MAX_BYTES = 72

  before_validation :normalize_attributes

  validates :email, presence: true, uniqueness: true, format: { with: EMAIL_FORMAT }
  validates :name, presence: true, length: { maximum: 100 }
  validates :password, length: { minimum: PASSWORD_MIN_LENGTH }, allow_nil: true
  validate :reject_whitespace_only_password
  validate :reject_password_exceeding_bcrypt_limit

  private

  def normalize_attributes
    self.email = email.to_s.strip
    self.name = name.to_s.strip
  end

  def reject_whitespace_only_password
    return if password.nil?

    errors.add(:password, 'is invalid') if password.strip.empty?
  end

  def reject_password_exceeding_bcrypt_limit
    return if password.nil?

    errors.add(:password, 'is too long') if password.bytesize > PASSWORD_MAX_BYTES
  end
end
