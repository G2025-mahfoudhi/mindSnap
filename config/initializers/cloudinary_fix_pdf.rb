# config/initializers/cloudinary_pdf_fix.rb
Rails.application.config.after_initialize do
  require 'active_storage/service/cloudinary_service'

  ActiveStorage::Service::CloudinaryService.class_eval do
    private

    def content_type_to_resource_type(content_type)
      return 'image' if content_type.nil?

      type, subtype = content_type.split('/')
      case type
      when 'video', 'audio'
        'video'
      when 'text', 'message'
        'raw'
      when 'application'
        case subtype
        when 'pdf', 'postscript'
          'raw'
        when 'vnd.apple.mpegurl', 'x-mpegurl', 'mpegurl'
          'video'
        else
          'raw'
        end
      else
        'image'
      end
    end
  end
end
end
