class Conversation < ApplicationRecord
  belongs_to :user
  has_many :messages, dependent: :destroy
  belongs_to :context, polymorphic: true, optional: true

  validates :name, presence: true

  def folder_scoped?
    context_type == "Folder" && context_id.present?
  end
end
