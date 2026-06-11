# Job asynchrone de résumé automatique avec streaming token-par-token.
# Diffuse chaque batch via Turbo Streams → affichage progressif côté client.
class SummarizeDocumentJob < ApplicationJob
  queue_as :ai

  FLUSH_INTERVAL = 0.05
  FLUSH_SIZE = 12

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

    # Un seul broadcast final (version définitive, nettoyée) — évite le double
    # déclenchement du MutationObserver qui ferait réapparaître / disparaître
    # le bouton "Dossier suggéré".
    final = accumulated.strip.presence || "Résumé temporairement indisponible. Veuillez réessayer."
    broadcast_summary(document, final)
    document.update!(summary: final)
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
    Time.current - last_flush >= FLUSH_INTERVAL ||
      buffer.length >= FLUSH_SIZE ||
      buffer.match?(/[\s.,!?;:\n]$/)
  end

  def broadcast_summary(document, text)
    document.update_columns(summary: text)
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
    length = document.user.summary_length

    <<~PROMPT
      #{summary_instructions(extracted_count, length)}
      #{folder_instruction}
      Contenu :
      #{document.content.truncate(extracted_count * 4_000)}
    PROMPT
  end

  def summary_instructions(file_count, length = "medium") # rubocop:disable Metrics/MethodLength
    if file_count > 1
      per_file = case length
                 when "short" then "1 phrase par fichier"
                 when "detailed" then "3 à 4 phrases par fichier"
                 else "1 à 2 phrases par fichier"
                 end
      <<~INST.strip
        Ce document regroupe #{file_count} fichiers attachés.
        Rédige un résumé structuré en deux parties :
        1. Une synthèse globale en 1 phrase.
        2. Pour chaque fichier (identifié entre crochets dans le contenu), #{per_file} résumant son contenu essentiel — sur une seule ligne, sans saut de ligne après le titre, format strict : **Fichier N – nomfichier :** résumé ici.
        Sois factuel. Ne commence pas par "Ce document" ou "L'auteur".
      INST
    else
      case length
      when "short"
        <<~INST.strip
          Résume le document suivant en 3 phrases maximum.
          Sois concis et factuel. Ne commence pas par "Ce document..."
          ou "L'auteur...". Va directement au contenu essentiel.
        INST
      when "detailed"
        <<~INST.strip
          Résume le document suivant en 2 à 3 paragraphes détaillés.
          Sois factuel et structuré. Ne commence pas par "Ce document..."
          ou "L'auteur...". Couvre les points essentiels en profondeur.
        INST
      else
        <<~INST.strip
          Résume le document suivant en 5 à 6 phrases.
          Sois concis et factuel. Ne commence pas par "Ce document..."
          ou "L'auteur...". Va directement au contenu essentiel.
        INST
      end
    end
  end

  def build_folder_instruction(document) # rubocop:disable Metrics/MethodLength
    return "" if document.folder_id.present?

    folders = document.user.folders.includes(:parent).order(:name)
    return "" if folders.empty?

    folder_list = folders.map do |f|
      f.parent ? "  └─ #{f.name} (dans #{f.parent.name})" : "- #{f.name}"
    end.join("\n")

    file_count = document.content.to_s.scan(/\[Fichier \d+/).size
    multi = file_count > 1

    if multi
      <<~SECTION

        Après le résumé, analyse les thèmes de chaque fichier et ajoute des suggestions de classement.

        Règles strictes :
        - Si tous les fichiers ont un thème similaire : une seule ligne **📁 Dossier suggéré :** NomDossier
        - Si les fichiers ont des thèmes différents : une ligne par fichier avec le format **📁 Dossier suggéré :** NomDossier (répète ce format autant de fois que nécessaire, une ligne par fichier)
        - Si les thèmes sont vraiment distincts, ajoute aussi : **✂️ Séparation suggérée :** brève description (ex: "Fichier 1 → NomDossier1, Fichier 2 → NomDossier2")
        - Utilise uniquement les noms de dossiers listés ci-dessous, sans guillemets ni ponctuation supplémentaire.
        - Ne suggère pas de dossier si aucun ne correspond.

        Dossiers disponibles :
        #{folder_list}

      SECTION
    else
      <<~SECTION

        Après le résumé, ajoute sur une nouvelle ligne séparée la suggestion de dossier la plus pertinente pour classer ce document.
        Format exact : **📁 Dossier suggéré :** NomDossier
        Utilise uniquement les noms de dossiers listés ci-dessous, sans guillemets ni ponctuation supplémentaire.

        Dossiers disponibles :
        #{folder_list}

      SECTION
    end
  end
end
