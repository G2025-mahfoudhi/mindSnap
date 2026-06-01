class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.text :content
      t.string :role
      t.references :conversation, null: false, foreign_key: true

      t.timestamps
    end
  end
end
