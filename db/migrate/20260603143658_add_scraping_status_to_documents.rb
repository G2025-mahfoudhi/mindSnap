class AddScrapingStatusToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :scraping_status, :string
  end
end
