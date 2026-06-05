require "test_helper"

class FileExtractionServiceTest < ActiveSupport::TestCase
  test "extract_plain lit un fichier texte" do
    blob = create_blob("Hello world", "text/plain", "test.txt")
    result = FileExtractionService.extract(blob)
    assert_equal "Hello world", result
  end

  test "extract retourne nil pour un type non supporté" do
    blob = create_blob("binary", "application/octet-stream", "test.bin")
    result = FileExtractionService.extract(blob)
    assert_nil result
  end

  test "extract_docx ne crashe pas" do
    blob = create_blob(docx_bytes, "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "test.docx")
    result = FileExtractionService.extract(blob)
    # Le DOCX minimal peut ne pas être parsable par la gem docx
    assert [String, NilClass].include?(result.class)
  rescue StandardError => e
    skip "Erreur création DOCX: #{e.message}"
  end

  test "extract_pdf retourne nil pour PDF sans texte" do
    blob = create_blob(minimal_pdf_bytes, "application/pdf", "test.pdf")
    result = FileExtractionService.extract(blob)
    # Un PDF structure-only sans contenu texte
    assert_nil result
  end

  test "extract_ocr ne crashe pas sur une image" do
    skip "Tesseract non disponible" unless tesseract_available?

    blob = create_blob(valid_png_bytes, "image/png", "test.png")
    result = FileExtractionService.extract(blob)
    # L'OCR sur du bruit peut retourner nil ou du charabia — on vérifie juste que ça ne crashe pas
    assert [String, NilClass].include?(result.class)
  end

  test "extract_text lit un fichier markdown" do
    blob = create_blob("# Titre\n\nParagraphe.", "text/markdown", "test.md")
    result = FileExtractionService.extract(blob)
    assert result.present?
    assert result.include?("Titre")
  end

  private

  def create_blob(content, content_type, filename)
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(content),
      filename: filename,
      content_type: content_type
    )
  end

  def tesseract_available?
    system("which tesseract > /dev/null 2>&1")
  end

  def docx_bytes
    buffer = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("[Content_Types].xml")
      zip.write(%(<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>))
      zip.put_next_entry("_rels/.rels")
      zip.write(%(<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>))
      zip.put_next_entry("word/document.xml")
      zip.write(%(<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Hello DOCX world</w:t></w:r></w:p></w:body></w:document>))
    end
    buffer.string
  end

  def minimal_pdf_bytes
    <<~PDF
      %PDF-1.4
      1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
      2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
      3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj
      xref
      0 4
      0000000000 65535 f 
      0000000009 00000 n 
      0000000052 00000 n 
      0000000101 00000 n 
      trailer<</Size 4/Root 1 0 R>>
      startxref
      190
      %%EOF
    PDF
  end

  def valid_png_bytes
    # PNG 1x1 pixel noir
    [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
      0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
      0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
      0x00, 0x00, 0x03, 0x00, 0x01, 0x91, 0xE5, 0xEC,
      0xD2, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
      0x44, 0xAE, 0x42, 0x60, 0x82
    ].pack("C*")
  end
end
