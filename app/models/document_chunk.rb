class DocumentChunk < ApplicationRecord
  belongs_to :document

  has_neighbors :embedding

  validates :chunk_index, presence: true
  validates :content, presence: true
end
