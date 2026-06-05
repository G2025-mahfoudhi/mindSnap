class SetDefaultScrapingStatus < ActiveRecord::Migration[8.1]
  def change
    change_column_default :documents, :scraping_status, from: nil, to: "pending"
  end
end
