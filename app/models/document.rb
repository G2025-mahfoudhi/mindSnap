class Document < ApplicationRecord
  belongs_to :user
  belongs_to :folder, optional: true

  has_many_attached :file

  validates :title, presence: true
  validates :document_type, presence: true

  before_save :set_pdf_resource_type

  private

  def set_pdf_resource_type
    file.each do |attachment|
      if attachment.blob.content_type == "application/pdf"
        attachment.blob.metadata["resource_type"] = "raw"
      end
    end
  end
end
