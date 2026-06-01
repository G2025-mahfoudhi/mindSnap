class ChangeDocumentsFolderReferences < ActiveRecord::Migration[8.1]
  def change
    change_column_null :documents, :folder_id, true
  end
end
