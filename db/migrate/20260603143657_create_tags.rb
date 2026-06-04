class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false, limit: 50
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :tags, [:name, :user_id], unique: true

    create_table :taggings do |t|
      t.references :tag, null: false, foreign_key: { on_delete: :cascade }
      t.references :taggable, polymorphic: true, null: false
      t.timestamps
    end
    add_index :taggings, [:tag_id, :taggable_type, :taggable_id],
      unique: true,
      name: "idx_taggings_unique"
  end
end
