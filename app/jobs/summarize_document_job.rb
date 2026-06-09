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

    <<~PROMPT
      Résume le document suivant en 3 phrases maximum.
      Sois concis et factuel. Ne commence pas par "Ce document..."
      ou "L'auteur...". Va directement au contenu essentiel.
      #{folder_instruction}
      Document :
      #{document.content.truncate(4000)}
    PROMPT
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
