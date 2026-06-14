class CreateClients < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'pgcrypto'

    create_table :clients, id: :uuid do |t|
      t.uuid :client_id, null: false
      t.string :client_secret_hash, null: false
      t.string :name, null: false
      t.text :redirect_uris, null: false
      t.text :allowed_scopes, null: false
      t.timestamps
    end

    add_index :clients, :client_id, unique: true
  end
end
