class Document < ApplicationRecord
  # -- Associations --------------------------------------------------------
  belongs_to :user
  belongs_to :folder, optional: true

  has_many_attached :file, dependent: :purge_later
  has_many :document_chunks, dependent: :destroy
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  # -- Validations ---------------------------------------------------------
  validates :title, presence: true
  validates :document_type, presence: true

  # -- Callbacks -----------------------------------------------------------
  # Après création : si c'est un Lien avec URL, scraper le contenu
  after_commit :scrape_async, on: :create

  # Après création/mise à jour : générer les embeddings vectoriels
  # Uniquement si le contenu a changé ou si le document n'a jamais été embeddé
  after_commit :embed_async, on: [:create, :update], if: :should_reembed?

  # -- Scopes & Predicates -------------------------------------------------
  def embedded?
    embedding_status == "completed"
  end

  private

  # Déclenche le scraping uniquement pour les documents de type "Lien"
  # qui ont une URL source mais pas encore de contenu
  def scrape_async
    return unless document_type == "Lien" && source_url.present? && content.blank?
    ScrapeLinkJob.perform_later(id)
  end

  # Déclenche l'embedding du contenu du document (chunking + vecteurs)
  # Évite de ré-embedder si le contenu n'a pas changé (ex: mise à jour du résumé)
  def embed_async
    return if content.blank?
    EmbedDocumentJob.perform_later(id)
  end

  # Évite les boucles : ne ré-embede pas quand un job modifie le document
  # (ex: SummarizeDocumentJob qui écrit le résumé)
  def should_reembed?
    content.present? && (
      embedding_status == "pending" ||
      saved_change_to_content?
    )
  end
end
