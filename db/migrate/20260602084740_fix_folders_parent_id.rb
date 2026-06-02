class FixFoldersParentId < ActiveRecord::Migration[8.1]
  def change
    rename_column :folders, :folder_id, :parent_id
    change_column_null :folders, :parent_id, true
  end
end
