class AddAuthTimeToAuthorizationCodes < ActiveRecord::Migration[8.1]
  def change
    add_column :authorization_codes, :auth_time, :datetime
  end
end
