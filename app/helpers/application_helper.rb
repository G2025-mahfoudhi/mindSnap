module ApplicationHelper
  def doc_icon(document)
    case document.document_type
    when "PDF"      then "fa-file-pdf"
    when "Lien"     then "fa-link"
    when "Image"    then "fa-file-image"
    when "Note"     then "fa-file-lines"
    else                 "fa-file"
    end
  end

  def markdown(text)
    return "" if text.blank?

    renderer = ::Redcarpet::Render::HTML.new(
      hard_wrap: true,
      link_attributes: { target: "_blank", rel: "noopener noreferrer" }
    )
    parser = ::Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      no_intra_emphasis: true,
      space_after_headers: true
    )
    raw parser.render(text)
  end
end
