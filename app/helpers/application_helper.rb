module ApplicationHelper
  def asset_exists?(path)
    if Rails.application.config.assets.compile
      Rails.application.assets&.find_asset(path).present?
    else
      Rails.application.assets_manifest.assets[path].present?
    end
  end

  def avatar_url(attachment)
    return nil unless attachment.attached? && attachment.blob.persisted?

    if attachment.blob.service_name == "cloudinary"
      key = "#{Rails.env}/#{attachment.blob.key}"
      Cloudinary::Utils.cloudinary_url(key, resource_type: "image", type: "upload", secure: true)
    else
      url_for(attachment)
    end
  end

  def document_inline_url(attachment)
    if attachment.blob.service_name == "cloudinary"
      key = "#{Rails.env}/#{attachment.blob.key}"
      Cloudinary::Utils.cloudinary_url(key, resource_type: "image", type: "upload", secure: true)
    else
      url_for(attachment)
    end
  end

  def doc_icon(document)
    case document.document_type
    when "PDF"      then "fa-file-pdf"
    when "Lien"     then "fa-link"
    when "Image"    then "fa-file-image"
    when "Note"     then "fa-file-lines"
    else                 "fa-file"
    end
  end

  # Affiche une heure en heure locale du navigateur via JS.
  # Fallback : heure serveur (Paris) si JS désactivé.
  # format: :time → "15:30"  |  :date → "11/06/2026"  |  :datetime → "11/06/2026 à 15:30"
  def local_time(datetime, format = :time)
    return "" unless datetime

    fallback = case format
               when :date     then datetime.strftime("%d/%m/%Y")
               when :datetime then datetime.strftime("%d/%m/%Y à %H:%M")
               else                datetime.strftime("%H:%M")
               end

    tag.time(fallback,
             datetime: datetime.utc.iso8601,
             data: { localtime: format })
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

  # Version streaming : ferme les marqueurs inline non terminés avant de passer
  # à Redcarpet. Évite d'afficher ** ou * bruts pendant la génération.
  # Ordre important : traiter ** avant * pour éviter le double-comptage.
  def streaming_markdown(text)
    str = text.to_s
    return "".html_safe if str.blank?

    padded = str.dup
    %w[** __ * _ `].each do |m|
      padded += m if padded.scan(m).length.odd?
    end

    markdown(padded)
  end
end
