class ExportService
  FONTS_PATH = Rails.root.join("app/assets/fonts").freeze

  def initialize(user)
    @user = user
  end

  def json_export
    JSON.pretty_generate(build_export_data)
  end

  def json_export_by_tags(tags)
    docs = documents_for_tags(tags)
    JSON.pretty_generate({
      exported_at: Time.current.iso8601,
      tag_count: tags.size,
      tags: tags.map(&:name),
      document_count: docs.size,
      documents: docs.map { |d| serialize_document(d) }
    })
  end

  def markdown_export_zip
    require "zip"
    docs = @user.documents.includes(:tags, :folder).order(:created_at)
    conversations = @user.conversations.includes(:messages).order(:created_at)

    Zip::OutputStream.write_buffer do |zio|
      write_zip_readme(zio, docs.size, conversations.size)
      write_zip_documents(zio, docs)
      write_zip_conversations(zio, conversations)
    end.string
  end

  def pdf_export
    require "prawn"
    docs = @user.documents.includes(:tags, :folder).order(:created_at)
    conversations = @user.conversations.includes(:messages).order(:created_at)

    build_pdf do |pdf|
      pdf_cover(pdf, "Export MindSnap", "#{docs.size} document(s) — #{conversations.size} conversation(s)")
      pdf_documents_section(pdf, docs)
      pdf_conversations_section(pdf, conversations)
    end
  end

  def pdf_export_by_tags(tags)
    require "prawn"
    docs = documents_for_tags(tags)

    build_pdf do |pdf|
      pdf_cover(pdf, "Export MindSnap — Tags", "Tags : #{tags.map(&:name).join(', ')}\n#{docs.size} document(s)")
      pdf_documents_section(pdf, docs)
    end
  end

  def markdown_export_by_tags_zip(tags)
    require "zip"
    docs = documents_for_tags(tags)

    Zip::OutputStream.write_buffer do |zio|
      zio.put_next_entry("README.txt")
      zio.write("Export MindSnap par tags — #{Time.current.strftime('%d/%m/%Y %H:%M')}\n")
      zio.write("Tags: #{tags.map(&:name).join(', ')}\n")
      zio.write("#{docs.size} document(s)\n")

      docs.each do |doc|
        write_zip_single_doc(zio, doc, "")
      end
    end.string
  end

  private

  def documents_for_tags(tags)
    Document.joins(:taggings)
            .where(taggings: { tag: tags })
            .where(user: @user)
            .distinct
            .includes(:tags, :folder)
  end

  def build_export_data
    docs = @user.documents.includes(:tags, :folder).order(:created_at)
    conversations = @user.conversations.includes(:messages).order(:created_at)

    {
      exported_at: Time.current.iso8601,
      user: {
        email: @user.email,
        first_name: @user.first_name,
        last_name: @user.last_name
      },
      stats: {
        document_count: docs.size,
        folder_count: @user.folders.count,
        conversation_count: conversations.size,
        message_count: @user.messages.count,
        tag_count: @user.tags.count
      },
      documents: docs.map { |d| serialize_document(d) },
      conversations: conversations.map { |c| serialize_conversation(c) }
    }
  end

  def serialize_document(doc)
    {
      id: doc.id,
      title: doc.title,
      document_type: doc.document_type,
      content: doc.content,
      summary: doc.summary,
      folder: doc.folder&.name,
      tags: doc.tags.map(&:name),
      created_at: doc.created_at.iso8601,
      updated_at: doc.updated_at.iso8601
    }
  end

  def serialize_conversation(conv)
    {
      id: conv.id,
      name: conv.name,
      context_type: conv.context_type,
      created_at: conv.created_at.iso8601,
      messages: conv.messages.order(:created_at).map do |m|
        { role: m.role, content: m.content, created_at: m.created_at.iso8601 }
      end
    }
  end

  def write_zip_readme(zio, doc_count, conv_count)
    zio.put_next_entry("README.txt")
    zio.write("Export MindSnap — #{Time.current.strftime('%d/%m/%Y %H:%M')}\n")
    zio.write("#{doc_count} document(s) — #{conv_count} conversation(s)\n")
  end

  def write_zip_documents(zio, docs)
    return if docs.empty?

    zio.put_next_entry("documents/")
    docs.each do |doc|
      path_prefix = "documents/#{safe_doc_name(doc)}"
      zio.put_next_entry("#{path_prefix}.md")
      zio.write(document_to_markdown(doc))
      attach_doc_files(zio, doc, path_prefix)
    end
  end

  def write_zip_conversations(zio, conversations)
    return if conversations.empty?

    zio.put_next_entry("conversations/")
    conversations.each do |conv|
      zio.put_next_entry("conversations/#{safe_conv_name(conv)}.md")
      zio.write(conversation_to_markdown(conv))
    end
  end

  def write_zip_single_doc(zio, doc, _prefix)
    name = safe_doc_name(doc)
    zio.put_next_entry("#{name}.md")
    zio.write(document_to_markdown(doc))
    attach_doc_files(zio, doc, name)
  end

  def attach_doc_files(zio, doc, prefix)
    doc.file.each do |file|
      next unless file.attached?

      ext = File.extname(file.filename.to_s).presence || ".bin"
      zio.put_next_entry("#{prefix}#{ext}")
      zio.write(file.download)
    rescue StandardError => e
      Rails.logger.warn("Export: impossible de lire #{file.filename}: #{e.message}")
    end
  end

  def safe_doc_name(doc)
    doc.title.parameterize.presence || "doc_#{doc.id}"
  end

  def safe_conv_name(conv)
    conv.name.parameterize.presence || "conv_#{conv.id}"
  end

  def document_to_markdown(doc)
    parts = []
    parts << "# #{doc.title}"
    parts << ""
    parts << "**Type** : #{doc.document_type}"
    parts << "**Dossier** : #{doc.folder&.name || 'Aucun'}"
    parts << "**Tags** : #{doc.tags.map(&:name).join(', ')}" if doc.tags.any?
    parts << "**Créé le** : #{I18n.l(doc.created_at, format: :long)}"
    parts << ""
    parts << "## Résumé"
    parts << (doc.summary.presence || "Aucun résumé.")
    parts << ""
    parts << "## Contenu"
    parts << (doc.content.presence || "Aucun contenu textuel.")
    parts.join("\n")
  end

  def markdown_to_plain(text)
    return "" if text.blank?

    text
      .gsub(/^\#{1,6}\s+/, "")
      .gsub(/\*\*(.*?)\*\*/m, '\1')
      .gsub(/\*(.*?)\*/m, '\1')
      .gsub(/~~(.*?)~~/m, '\1')
      .gsub(/`{1,3}.*?`{1,3}/m, "")
      .gsub(/^\s*[-*+]\s+/, "• ")
      .gsub(/^\s*\d+\.\s+/, "")
      .gsub(/\[([^\]]+)\]\([^)]+\)/, '\1')
      .gsub(/!\[[^\]]*\]\([^)]+\)/, "")
      .gsub(/^>\s*/, "")
      .gsub(/^-{3,}$/, "")
      .gsub(/\n{3,}/, "\n\n")
      .strip
  end

  def build_pdf(&block)
    Prawn::Document.new(page_size: "A4", margin: [40, 50, 40, 50]) do |pdf|
      pdf.font_families.update(
        "DejaVu" => {
          normal: FONTS_PATH.join("DejaVuSans.ttf").to_s,
          bold: FONTS_PATH.join("DejaVuSans-Bold.ttf").to_s
        }
      )
      pdf.font "DejaVu"
      block.call(pdf)
    end.render
  end

  def pdf_cover(pdf, title, subtitle)
    pdf.font_size(24) { pdf.text title, style: :bold, align: :center }
    pdf.move_down 8
    pdf.font_size(11) { pdf.text subtitle, color: "555555", align: :center }
    pdf.move_down 6
    pdf.font_size(10) { pdf.text Time.current.strftime('%d/%m/%Y %H:%M'), color: "888888", align: :center }
    pdf.move_down 20
    pdf.stroke_horizontal_rule
    pdf.move_down 20
  end

  def pdf_documents_section(pdf, docs)
    return if docs.empty?

    pdf.font_size(16) { pdf.text "Documents", style: :bold }
    pdf.move_down 12

    docs.each_with_index do |doc, i|
      pdf.start_new_page if i.positive?
      pdf.font_size(14) { pdf.text doc.title, style: :bold }
      pdf.move_down 4
      pdf.font_size(9) do
        pdf.text "Type : #{doc.document_type} | Dossier : #{doc.folder&.name || 'Aucun'}", color: "666666"
        pdf.text "Tags : #{doc.tags.map(&:name).join(', ')}" if doc.tags.any?
        pdf.text "Créé le : #{doc.created_at.strftime('%d/%m/%Y')}", color: "888888"
      end
      pdf.move_down 8
      if doc.summary.present?
        pdf.font_size(11) { pdf.text "Résumé", style: :bold }
        pdf.move_down 4
        pdf.font_size(10) { pdf.text markdown_to_plain(doc.summary), leading: 3 }
        pdf.move_down 8
      end
      if doc.content.present?
        pdf.font_size(11) { pdf.text "Contenu", style: :bold }
        pdf.move_down 4
        pdf.font_size(9) { pdf.text doc.content.truncate(3000), leading: 3, color: "333333" }
      end
    end
  end

  def pdf_conversations_section(pdf, conversations)
    return if conversations.empty?

    pdf.start_new_page
    pdf.font_size(16) { pdf.text "Conversations", style: :bold }
    pdf.move_down 12

    conversations.each_with_index do |conv, i|
      pdf.start_new_page if i.positive?
      pdf.font_size(13) { pdf.text conv.name.presence || "Conversation #{conv.id}", style: :bold }
      pdf.move_down 4
      pdf.font_size(9) { pdf.text "Créée le : #{conv.created_at.strftime('%d/%m/%Y')}", color: "888888" }
      pdf.move_down 8

      conv.messages.order(:created_at).each do |msg|
        label = msg.role == "user" ? "Vous" : "MindSnap"
        color = msg.role == "user" ? "1a6b6a" : "333333"
        pdf.font_size(9) do
          pdf.text "#{label} — #{msg.created_at.strftime('%d/%m/%Y %H:%M')}", style: :bold, color: color
          pdf.move_down 2
          pdf.text markdown_to_plain(msg.content).truncate(1000), leading: 2, color: "444444"
          pdf.move_down 6
        end
      end
    end
  end

  def conversation_to_markdown(conv)
    parts = []
    parts << "# #{conv.name}"
    parts << ""
    parts << "**Créée le** : #{I18n.l(conv.created_at, format: :long)}"
    parts << "**Contexte** : #{conv.context_type || 'Général'}"
    parts << ""
    conv.messages.order(:created_at).each do |msg|
      role_label = msg.role == "user" ? "🧑 Vous" : "🤖 MindSnap"
      parts << "### #{role_label} — #{I18n.l(msg.created_at, format: :short)}"
      parts << ""
      parts << msg.content
      parts << ""
    end
    parts.join("\n")
  end
end
