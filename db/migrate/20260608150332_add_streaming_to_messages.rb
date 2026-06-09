class AddStreamingToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :streaming, :boolean, default: false, null: false
  end
end
