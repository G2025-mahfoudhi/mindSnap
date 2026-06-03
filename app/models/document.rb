class Document < ApplicationRecord
  belongs_to :user
  belongs_to :folder, optional: true

  has_many_attached :file
  has_many :document_chunks, dependent: :destroy
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  validates :title, presence: true
  validates :document_type, presence: true

  after_commit :scrape_async, on: :create
  after_commit :embed_async, on: [:create, :update]

  def embedded?
    embedding_status == "completed"
  end

  private

  def scrape_async
    return unless document_type == "Lien" && source_url.present? && content.blank?
    ScrapeLinkJob.perform_later(id)
  end

  def embed_async
    return if content.blank?
    EmbedDocumentJob.perform_later(id)
  end
end
