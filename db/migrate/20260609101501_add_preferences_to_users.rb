class AddPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :preferred_language, :string, default: "fr"
    add_column :users, :summary_length, :string, default: "medium"
    add_column :users, :auto_tagging, :boolean, default: true
    add_column :users, :tts_voice, :string, default: "ff_siwis"
    add_column :users, :default_view, :string, default: "grid"
  end
end
