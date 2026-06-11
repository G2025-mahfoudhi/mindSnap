class FileExtractionService # rubocop:disable Metrics/ClassLength
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

  # Cascade : pdf-reader → pdftotext (poppler) → OCR image.
  # Chaque étape est isolée : une erreur sur l'une n'empêche pas les suivantes.
  # pdftotext est particulièrement fiable pour les PDFs issus d'une impression
  # de page HTML (Chrome, Firefox) qui encodent le texte nativement.
  def extract_pdf # rubocop:disable Metrics/MethodLength
    with_tempfile(".pdf") do |path|
      reader_text  = safe_pdf_reader(path)
      poppler_text = pdftotext_extract(path)

      best = [reader_text, poppler_text].compact.max_by(&:length)
      return best if best.to_s.length >= 50

      Rails.logger.info "FileExtractionService: PDF court (#{best.to_s.length} chars), tentative OCR"
      ocr_text = extract_pdf_ocr(path)
      [best, ocr_text].compact.max_by { |t| t.to_s.length }.presence
    end
  rescue StandardError => e
    Rails.logger.warn "FileExtractionService: PDF extraction — #{e.message}"
    nil
  end

  def safe_pdf_reader(path)
    reader = PDF::Reader.new(path)
    reader.pages.map(&:text).join("\n\n").strip
  rescue StandardError => e
    Rails.logger.warn "FileExtractionService: pdf-reader — #{e.message}"
    nil
  end

  # pdftotext (poppler-utils) : extrait le texte natif sans conversion image.
  # Retourne nil si pdftotext n'est pas installé (Errno::ENOENT).
  def pdftotext_extract(path)
    require "open3"
    out, _err, status = Open3.capture3(
      "pdftotext", "-layout", "-enc", "UTF-8", path, "-"
    )
    out.strip.presence if status.success?
  rescue Errno::ENOENT
    nil # pdftotext non disponible sur ce système
  rescue StandardError => e
    Rails.logger.warn "FileExtractionService: pdftotext — #{e.message}"
    nil
  end

  # OCR via ImageMagick (PDF → PNG) + Tesseract. Limité aux 10 premières pages
  # pour éviter les timeouts sur les gros documents.
  def extract_pdf_ocr(pdf_path) # rubocop:disable Metrics/MethodLength
    pages_text = []
    pdf = MiniMagick::Image.open(pdf_path)
    pdf.pages.first(10).each do |page|
      page_path = File.join(Dir.tmpdir, "mind_pdf_#{SecureRandom.hex(4)}.png")
      page.format("png")
      page.write(page_path)
      text = RTesseract.new(page_path, lang: "fra+eng").to_s.strip
      pages_text << text if text.present?
    ensure
      FileUtils.rm_f(page_path) if page_path
    end
    pages_text.join("\n\n").presence
  rescue StandardError => e
    Rails.logger.warn "FileExtractionService: OCR PDF — #{e.message}"
    nil
  end

  def extract_docx
    with_tempfile(".docx") do |path|
      doc = Docx::Document.open(path)
      doc.paragraphs.map(&:text).join("\n").strip
    end
  rescue StandardError => e
    Rails.logger.warn "FileExtractionService: DOCX — #{e.message}"
    nil
  end

  def extract_ocr
    with_tempfile(guess_extension) do |path|
      RTesseract.new(path, lang: "fra+eng").to_s.strip
    end
  rescue StandardError => e
    Rails.logger.warn "FileExtractionService: OCR image — #{e.message}"
    nil
  end

  def extract_plain
    with_tempfile(guess_extension) do |path|
      raw = File.binread(path)
      raw.force_encoding("UTF-8")
      raw = raw.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?") unless raw.valid_encoding?
      raw.strip
    end
  rescue StandardError => e
    Rails.logger.warn "FileExtractionService: texte brut — #{e.message}"
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
    folder = Rails.env
    full_key = "#{folder}/#{@blob.key}"

    %w[image raw].each do |resource_type|
      url = Cloudinary::Utils.cloudinary_url(full_key, resource_type: resource_type, type: "upload", secure: true)
      response = Faraday.get(url)
      return response.body if response.success? && response.body.present?
    end

    @blob.download
  rescue StandardError
    @blob.download
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
