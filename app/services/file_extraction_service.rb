class FileExtractionService
  def self.extract(blob)
    new(blob).extract
  end

  def initialize(blob)
    @blob = blob
    @content_type = blob.content_type.to_s
  end

  def extract
    case @content_type
    when "application/pdf"              then extract_pdf
    when /\Atext\//                     then extract_plain
    when %r{application/vnd.openxmlformats-officedocument.wordprocessingml.document}
      extract_docx
    when /\Aimage\//                    then extract_ocr
    else
      Rails.logger.info "FileExtractionService: type non supporté #{@content_type}"
      nil
    end
  end

  private

  def extract_pdf
    with_tempfile(".pdf") do |path|
      reader = PDF::Reader.new(path)
      text = reader.pages.map(&:text).join("\n\n").strip

      if text.length < 50
        Rails.logger.info "FileExtractionService: PDF semble scanné, tentative OCR"
        extract_pdf_ocr(path)
      else
        text
      end
    end
  rescue PDF::Reader::MalformedPDFError => e
    Rails.logger.warn "FileExtractionService: PDF malformé — #{e.message}"
    nil
  end

  def extract_pdf_ocr(pdf_path)
    pages_text = []
    pdf = MiniMagick::Image.open(pdf_path)
    pdf.pages.each_with_index do |page, idx|
      page_path = File.join(Dir.tmpdir, "mind_pdf_#{SecureRandom.hex(4)}.png")
      page.format("png")
      page.write(page_path)
      text = RTesseract.new(page_path, lang: "fra").to_s.strip
      pages_text << text if text.present?
      File.delete(page_path) if File.exist?(page_path)
    end
    pages_text.join("\n\n")
  rescue StandardError => e
    Rails.logger.warn "FileExtractionService: OCR PDF échoué — #{e.message}"
    nil
  end

  def extract_docx
    with_tempfile(".docx") do |path|
      doc = Docx::Document.open(path)
      doc.paragraphs.map(&:text).join("\n").strip
    end
  rescue StandardError => e
    Rails.logger.warn "FileExtractionService: DOCX échoué — #{e.message}"
    nil
  end

  def extract_ocr
    with_tempfile(guess_extension) do |path|
      RTesseract.new(path, lang: "fra").to_s.strip
    end
  rescue StandardError => e
    Rails.logger.warn "FileExtractionService: OCR image échoué — #{e.message}"
    nil
  end

  def extract_plain
    with_tempfile(guess_extension) do |path|
      # Lit en binaire puis force l'UTF-8 en remplaçant les octets invalides
      raw = File.binread(path)
      raw.force_encoding("UTF-8")
      unless raw.valid_encoding?
        raw = raw.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
      end
      raw.strip
    end
  rescue StandardError => e
    Rails.logger.warn "FileExtractionService: lecture texte échouée — #{e.message}"
    nil
  end

  def with_tempfile(ext = "")
    tmp = Tempfile.new(["mind_extract", ext], binmode: true)
    tmp.write(download_blob)
    tmp.flush
    tmp.rewind
    yield(tmp.path)
  ensure
    tmp&.close
    tmp&.unlink
  end

  def download_blob
    # Active Storage Cloudinary retourne parfois 0 bytes via .download
    # On télécharge directement via l'URL Cloudinary avec le bon resource_type
    resource_type = cloudinary_resource_type
    url = Cloudinary::Utils.cloudinary_url(
      @blob.key,
      resource_type: resource_type,
      type: "upload",
      secure: true
    )
    response = Faraday.get(url)
    return response.body if response.success? && response.body.present?

    # Fallback sur Active Storage
    @blob.download
  rescue StandardError
    @blob.download
  end

  def cloudinary_resource_type
    case @content_type
    when /\Aimage\// then "image"
    when /\Avideo\// then "video"
    when "application/pdf" then "image"
    else "raw"
    end
  end

  def guess_extension
    case @content_type
    when "image/png"  then ".png"
    when "image/jpeg" then ".jpg"
    when "image/gif"  then ".gif"
    when "image/webp" then ".webp"
    when "text/plain" then ".txt"
    when "text/markdown", "text/x-markdown" then ".md"
    else ""
    end
  end
end
