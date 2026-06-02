class RenameTypeToDocumentTypeInDocuments < ActiveRecord::Migration[8.1]
  def change
    rename_column :documents, :type, :document_type
  end
end
