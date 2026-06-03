class Document < ApplicationRecord
  belongs_to :user
  belongs_to :folder, optional: true

  has_many_attached :file

  validates :title, presence: true
  validates :document_type, presence: true
end
