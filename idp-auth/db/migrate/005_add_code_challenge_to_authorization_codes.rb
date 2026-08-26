class AddCodeChallengeToAuthorizationCodes < ActiveRecord::Migration[7.0]
  def change
    add_column :authorization_codes, :code_challenge, :string
    add_column :authorization_codes, :code_challenge_method, :string
  end
end