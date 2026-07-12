require 'bcrypt'

class User
  class PasswordService
    def self.hash(password)
      BCrypt::Password.create(password).to_s
    end

    def self.verify?(password, password_digest)
      return false if password.blank? || password_digest.blank?

      BCrypt::Password.new(password_digest.to_s) == password
    rescue BCrypt::Errors::InvalidHash
      false
    end
  end
end
