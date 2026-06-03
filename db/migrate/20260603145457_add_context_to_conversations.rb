class AddContextToConversations < ActiveRecord::Migration[8.1]
  def change
    add_column :conversations, :context_type, :string
    add_column :conversations, :context_id, :bigint
    add_column :conversations, :model, :string,
      default: "nvidia/nemotron-3-super-120b-a12b:free"

    add_index :conversations, [:context_type, :context_id]
  end
end
