class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.string :title
      t.text :content
      t.string :type
      t.references :user, null: false, foreign_key: true
      t.references :folder, null: false, foreign_key: true
      t.datetime :date_injection

      t.timestamps
    end
  end
end
