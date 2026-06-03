# Représente un fragment de document avec son embedding vectoriel.
# Chaque document est découpé en chunks de ~512 tokens pour la recherche RAG.
# Le vecteur embedding (1024 dimensions) est stocké via pgvector et indexé par HNSW.
class DocumentChunk < ApplicationRecord
  belongs_to :document

  # Active la recherche de voisins par similarité cosinus (gem neighbor + pgvector)
  has_neighbors :embedding

  validates :chunk_index, presence: true
  validates :content, presence: true
end
