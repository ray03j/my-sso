class CreateConsents < ActiveRecord::Migration[7.1]
  def change
    create_table :consents do |t|
      t.string :user_id, null: false
      t.string :client_id, null: false
      t.string :scope, null: false
      t.timestamps
    end

    add_index :consents, [:user_id, :client_id], unique: true
  end
end
