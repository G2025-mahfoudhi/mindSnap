class Document < ApplicationRecord
  belongs_to :user
  belongs_to :folder

  validates :title, presence: true
  validates :content, presence: true
  validates :type, presence: true
end
