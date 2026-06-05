class RemoveModelFromConversations < ActiveRecord::Migration[8.1]
  def up
    remove_column :conversations, :model
  end

  def down
    add_column :conversations, :model, :string, default: "deepseek/deepseek-v4-flash"
  end
end
