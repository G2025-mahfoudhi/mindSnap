class AllowOptionalFolderInDocuments < ActiveRecord::Migration[8.1]
  def change
    change_column_null :documents, :folder_id, true
    change_column_null :folders, :folder_id, true
  end
end