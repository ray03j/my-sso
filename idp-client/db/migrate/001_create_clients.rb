class CreateClients < ActiveRecord::Migration[7.1]
  def change
    create_table :clients do |t|
      t.string :client_id, null: false
      t.string :client_secret_hash, null: false
      t.string :name, null: false
      t.text :redirect_uris, null: false
      t.text :allowed_scopes, null: false
      t.timestamps
    end

    add_index :clients, :client_id, unique: true
  end
end
