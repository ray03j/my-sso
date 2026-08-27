class AddCodeChallengeToAuthorizationCodes < ActiveRecord::Migration[7.1]
  def change
    change_table :authorization_codes, bulk: true do |t|
      t.column :code_challenge, :string
      t.column :code_challenge_method, :string
    end
  end
end
