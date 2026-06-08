class Document < ApplicationRecord
  # -- Associations --------------------------------------------------------
  belongs_to :user
  belongs_to :folder, optional: true

  has_many_attached :file, dependent: :purge
  has_many :document_chunks, dependent: :destroy
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  # -- Validations ---------------------------------------------------------
  validates :title, presence: true
  validates :document_type, presence: true
  validates :source_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
                                   message: "doit être une URL valide" },
                         allow_blank: true

  # -- Callbacks -----------------------------------------------------------
  # Migre les anciens documents "Lien" où l'URL était stockée dans content
  before_save :migrate_legacy_url, if: :should_migrate_url?

  # Après création : si c'est un Lien avec URL, scraper le contenu
  after_commit :scrape_async, on: :create

  # Après migration legacy : déclencher le scraping pour les documents existants
  after_commit :scrape_after_migration, on: :update, if: :should_scrape_after_migration?

  # Après création : extraire le texte des fichiers joints (PDF, DOCX, images)
  after_commit :extract_text_async, on: :create, if: :should_extract_text?

  # Après création/mise à jour : générer les embeddings vectoriels
  # Uniquement si le contenu a changé ou si le document n'a jamais été embeddé
  after_commit :embed_async, on: %i[create update], if: :should_reembed?

  # Résumé IA déclenché indépendamment de l'embedding (évite que l'échec d'embedding bloque le résumé)
  after_commit :summarize_async, on: %i[create update], if: :should_summarize?

  # -- Scopes & Predicates -------------------------------------------------
  # Filtre full-text : retourne les documents dont le contenu matche la query.
  # Le scoring exact (ts_rank) est calculé côté Ruby dans RagService pour
  # éviter les injections SQL (Arel.sql refuse les user inputs depuis Rails 8).
  scope :full_text_search, lambda { |query|
    where("search_vector @@ plainto_tsquery('french', ?)", query)
  }

  def embedded?
    embedding_status == "completed"
  end

  private

  # Migration des anciens documents "Lien" : l'URL était stockée dans content
  # au lieu de source_url. On la déplace au prochain save.
  def should_migrate_url?
    document_type == "Lien" &&
      source_url.blank? &&
      content.present? &&
      content.match?(%r{\Ahttps?://})
  end

  def migrate_legacy_url
    self.source_url = content
    self.content = nil
    self.scraping_status = "pending"
  end

  def should_scrape_after_migration?
    saved_change_to_source_url? && source_url.present? && content.blank?
  end

  def scrape_after_migration
    ScrapeLinkJob.perform_later(id)
  end

  # Déclenche le scraping uniquement pour les documents de type "Lien"
  # qui ont une URL source mais pas encore de contenu
  def scrape_async
    return unless document_type == "Lien" && source_url.present? && content.blank?

    ScrapeLinkJob.perform_later(id)
  end

  # Déclenche l'extraction de texte pour les fichiers joints
  def should_extract_text?
    file.attached? && content.blank?
  end

  def extract_text_async
    ExtractTextJob.perform_later(id)
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

  def summarize_async
    SummarizeDocumentJob.perform_later(id)
  end

  # Génère le résumé dès que le contenu est disponible ou change, sauf si c'est
  # le job lui-même qui met à jour le résumé (évite la boucle infinie)
  def should_summarize?
    content.present? && saved_change_to_content? && !saved_change_to_summary?
  end
end
