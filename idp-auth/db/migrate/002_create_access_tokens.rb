class CreateAccessTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :access_tokens do |t|
      t.string :token, null: false
      t.uuid :user_id, null: false
      t.uuid :client_id, null: false
      t.string :scope
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :access_tokens, :token, unique: true
    add_index :access_tokens, [:user_id, :client_id]
  end
end
