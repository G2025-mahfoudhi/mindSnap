class AddSearchVectorToDocuments < ActiveRecord::Migration[8.1]
  def up
    # Colonne tsvector alimentée automatiquement par PostgreSQL :
    # - titre en weight A (plus important)
    # - content en weight B
    # Langue 'french' = stemming français ("france" matche "français", "française", etc.)
    execute <<~SQL
      ALTER TABLE documents
      ADD COLUMN search_vector tsvector
      GENERATED ALWAYS AS (
        setweight(to_tsvector('french', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('french', coalesce(content, '')), 'B')
      ) STORED;
    SQL

    # Index GIN pour la recherche full-text rapide (équivalent Lucene en PostgreSQL)
    add_index :documents, :search_vector, using: :gin, name: "index_documents_on_search_vector"
  end

  def down
    remove_index :documents, name: "index_documents_on_search_vector"
    remove_column :documents, :search_vector
  end
end
