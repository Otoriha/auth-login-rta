class CreateAuthentications < ActiveRecord::Migration[7.2]
  def change
    create_table :authentications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider
      t.string :uid
      t.text :access_token
      t.text :refresh_token
      t.datetime :expires_at
      t.json :info

      t.timestamps
    end
    add_index :authentications, :uid
  end
end
