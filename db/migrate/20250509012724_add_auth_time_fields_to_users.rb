class AddAuthTimeFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :auth_started_at, :datetime
    add_column :users, :auth_completed_at, :datetime
    add_column :users, :auth_duration, :integer
  end
end
