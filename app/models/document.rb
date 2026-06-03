class Document < ApplicationRecord
  belongs_to :user
  belongs_to :folder, optional: true

  has_many_attached :file
  has_many :document_chunks, dependent: :destroy

  validates :title, presence: true
  validates :document_type, presence: true

  after_commit :embed_async, on: [:create, :update]

  def embedded?
    embedding_status == "completed"
  end

  private

  def embed_async
    return if content.blank?
    EmbedDocumentJob.perform_later(id)
  end
end
