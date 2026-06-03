class ChunkingService
  CHUNK_SIZE = 512
  CHUNK_OVERLAP = 64

  def initialize(text)
    @text = text
  end

  def call
    paragraphs = @text.split(/\n{2,}/)
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
