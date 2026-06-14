class CreateConsents < ActiveRecord::Migration[7.1]
  def change
    create_table :consents do |t|
      t.uuid :user_id, null: false
      t.uuid :client_id, null: false
      t.string :scope, null: false
      t.timestamps
    end

    add_index :consents, %i[user_id client_id], unique: true
  end
end
