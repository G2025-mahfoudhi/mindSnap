# Job asynchrone de résumé automatique avec streaming token-par-token.
# Diffuse chaque batch via Turbo Streams → affichage progressif côté client.
class SummarizeDocumentJob < ApplicationJob
  queue_as :ai

  FLUSH_INTERVAL = 0.1  # secondes entre deux broadcasts
  FLUSH_SIZE     = 80   # chars

  def perform(document_id) # rubocop:disable Metrics/MethodLength
    document = Document.find(document_id)
    return if document.content.blank?

    accumulated = +""
    buffer      = +""
    last_flush  = Time.current

    LlmCallService.stream(build_prompt(document)) do |token|
      accumulated << token
      buffer      << token

      next unless should_flush?(last_flush, buffer)

      broadcast_summary(document, accumulated)
      buffer.clear
      last_flush = Time.current
    end

    broadcast_summary(document, accumulated) if buffer.present?

    final = accumulated.strip.presence || "Résumé temporairement indisponible. Veuillez réessayer."
    document.update!(summary: final)
    broadcast_summary(document, final)
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "SummarizeDocumentJob: document #{document_id} introuvable"
  rescue StandardError => e
    Rails.logger.error "SummarizeDocumentJob échec doc #{document_id}: #{e.message}"
    error = "Résumé temporairement indisponible. Veuillez réessayer."
    document&.update!(summary: error)
    broadcast_summary(document, error) if document
  end

  private

  def should_flush?(last_flush, buffer)
    Time.current - last_flush >= FLUSH_INTERVAL || buffer.length >= FLUSH_SIZE
  end

  def broadcast_summary(document, text)
    renderer = Redcarpet::Render::HTML.new(hard_wrap: true)
    parser   = Redcarpet::Markdown.new(renderer, autolink: true, tables: true,
                                                 fenced_code_blocks: true, strikethrough: true,
                                                 no_intra_emphasis: true)
    inner  = "<div class=\"markdown-content\">#{parser.render(text.to_s)}</div>"
    html   = "<div id=\"doc-summary-content\" data-summary-poll-target=\"content\">#{inner}</div>"

    Turbo::StreamsChannel.broadcast_replace_to(document, target: "doc-summary-content", html: html)
  rescue StandardError => e
    Rails.logger.warn "SummarizeDocumentJob: broadcast failed — #{e.message}"
  end

  def build_prompt(document)
    folder_instruction = build_folder_instruction(document)
    extracted_count = document.content.to_s.scan(/\[Fichier \d+/).size
    extracted_count = 1 if extracted_count.zero? && document.content.present?

    <<~PROMPT
      #{summary_instructions(extracted_count)}
      #{folder_instruction}
      Contenu :
      #{document.content.truncate(extracted_count * 4_000)}
    PROMPT
  end

  def summary_instructions(file_count) # rubocop:disable Metrics/MethodLength
    if file_count > 1
      <<~INST.strip
        Ce document regroupe #{file_count} fichiers attachés.
        Rédige un résumé structuré en deux parties :
        1. Une synthèse globale en 1 phrase.
        2. Pour chaque fichier (identifié entre crochets dans le contenu), 1 à 2 phrases résumant son contenu essentiel — sur une seule ligne, sans saut de ligne après le titre, format strict : **Fichier N – nomfichier :** résumé ici.
        Sois factuel. Ne commence pas par "Ce document" ou "L'auteur".
      INST
    else
      <<~INST.strip
        Résume le document suivant en 3 phrases maximum.
        Sois concis et factuel. Ne commence pas par "Ce document..."
        ou "L'auteur...". Va directement au contenu essentiel.
      INST
    end
  end

  def build_folder_instruction(document) # rubocop:disable Metrics/MethodLength
    return "" if document.folder_id.present?

    folders = document.user.folders.includes(:parent).order(:name)
    return "" if folders.empty?

    folder_list = folders.map do |f|
      f.parent ? "  └─ #{f.name} (dans #{f.parent.name})" : "- #{f.name}"
    end.join("\n")

    <<~SECTION

      Après le résumé, ajoute sur une nouvelle ligne séparée la suggestion de dossier la plus pertinente pour classer ce document.
      Format exact : **📁 Dossier suggéré :** NomDossier

      Dossiers disponibles :
      #{folder_list}

    SECTION
  end
end
