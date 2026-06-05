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
end
