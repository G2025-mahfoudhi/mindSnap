# Job asynchrone de suggestion automatique de tags.
# Appelle le LLM (via LlmCallService) pour suggérer 3-5 mots-clés,
# puis crée les tags et taggings associés au document.
class TagDocumentJob < ApplicationJob
  queue_as :ai

  MAX_TAGS = 5

  def perform(document_id)
    document = Document.find(document_id)
    return if document.content.blank?

    response = LlmCallService.oneshot(build_prompt(document.content))
    return if response.blank?

    tag_names = response
      .split(",")
      .map(&:strip)
      .map(&:downcase)
      .select(&:present?)
      .first(MAX_TAGS)

    tag_names.each do |name|
      tag = document.user.tags.find_or_create_by!(name: name)
      Tagging.find_or_create_by!(tag: tag, taggable: document)
    end
  rescue StandardError => e
    Rails.logger.error "TagDocumentJob échec doc #{document_id}: #{e.message}"
  end

  private

  def build_prompt(content)
    <<~PROMPT
      Suggère 3 à 5 mots-clés (tags) pour le document ci-dessous.
      Format de réponse : mot1, mot2, mot3
      Règles : minuscules, 1 à 3 mots maximum par tag, séparés par des virgules.

      Document :
      #{content.truncate(3000)}
    PROMPT
  end
end
