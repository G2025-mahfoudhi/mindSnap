Rails.application.config.after_initialize do
  require 'active_storage/service/cloudinary_service'

  ActiveStorage::Service::CloudinaryService.class_eval do
    def delete(key)
      key = find_blob_or_use_key(key)
      instrument :delete, key: key do
        Cloudinary::Uploader.destroy(
          full_public_id_internal(key),
          resource_type: "image",
          invalidate: true
        )
        Cloudinary::Uploader.destroy(
          full_public_id_internal(key),
          resource_type: "raw",
          invalidate: true
        )
        Cloudinary::Uploader.destroy(
          full_public_id_internal(key),
          resource_type: "video",
          invalidate: true
        )
      end
    end
  end
end
