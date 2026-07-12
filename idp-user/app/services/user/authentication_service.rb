class User
  class AuthenticationService
    def self.authenticate(email, password)
      user = User.find_by(email: email)
      return nil unless user

      return user if PasswordService.verify?(password, user.password_digest)

      nil
    end
  end
end
