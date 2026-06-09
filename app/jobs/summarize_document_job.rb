# Job asynchrone de résumé automatique.
# Appelle le LLM (via LlmCallService) pour générer un résumé de 3 phrases
# qui est stocké dans la colonne documents.summary.
class SummarizeDocumentJob < ApplicationJob
  queue_as :ai

  def perform(document_id)
    document = Document.find(document_id)
    return if document.content.blank?

    summary = LlmCallService.oneshot(build_prompt(document))
    if summary.present?
      document.update!(summary: summary.strip)
    else
      document.update!(summary: "Résumé temporairement indisponible. Veuillez réessayer.")
    end
  rescue StandardError => e
    Rails.logger.error "SummarizeDocumentJob échec doc #{document_id}: #{e.message}"
  end

  private

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
