class CreateDocumentChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :document_chunks do |t|
      t.references :document, null: false, foreign_key: { on_delete: :cascade }
      t.integer :chunk_index, null: false
      t.text :content, null: false
      t.integer :token_count
      t.column :embedding, :vector, limit: 1024
      t.timestamps
    end

    add_index :document_chunks, :embedding,
      using: :hnsw,
      opclass: :vector_cosine_ops,
      name: "idx_document_chunks_embedding"
  end
end
