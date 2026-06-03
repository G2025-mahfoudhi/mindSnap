class AddStatusToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :embedding_status, :string, default: "pending"
    add_column :documents, :summary, :text
    add_column :documents, :source_url, :string
  end
end
