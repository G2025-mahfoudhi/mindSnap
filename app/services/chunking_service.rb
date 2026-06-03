# Découpe un texte long en chunks de ~512 tokens avec chevauchement de 64 tokens.
# Chaque chunk préserve l'intégrité des phrases (pas de coupure en milieu de phrase).
# Utilisé par EmbedDocumentJob avant la génération des embeddings vectoriels.
class ChunkingService
  CHUNK_SIZE = 512        # tokens cibles par chunk (1 token ≈ 4 caractères)
  CHUNK_OVERLAP = 64      # chevauchement entre chunks consécutifs

  def initialize(text)
    @text = text
  end

  def call
    paragraphs = @text.split(/\n{2,}/)  # découpe par paragraphes
    chunks = []
    current = ""

    paragraphs.each do |para|
      if token_count(current + " " + para) > CHUNK_SIZE
        chunks << current.strip unless current.empty?
        current = overlap_from(current) + "\n\n" + para
      else
        current += "\n\n" + para
      end
    end
    chunks << current.strip unless current.empty?
    chunks
  end

  private

  def token_count(text)
    text.length / 4
  end

  # Récupère les dernières phrases pour le chevauchement entre chunks
  def overlap_from(text)
    sentences = text.split(/(?<=[.!?])\s+/)
    overlap = ""
    sentences.reverse_each do |s|
      break if token_count(overlap + s) > CHUNK_OVERLAP
      overlap = s + " " + overlap
    end
    overlap.strip
  end
end
