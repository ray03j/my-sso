class CreateAuthorizationCodes < ActiveRecord::Migration[7.1]
  def change
    create_table :authorization_codes do |t|
      t.string :code, null: false
      t.uuid :user_id, null: false
      t.uuid :client_id, null: false
      t.string :redirect_uri
      t.string :scope
      t.datetime :expires_at, null: false
      t.boolean :used, default: false, null: false
      t.timestamps
    end

    add_index :authorization_codes, :code, unique: true
    add_index :authorization_codes, %i[client_id used]
  end
end
