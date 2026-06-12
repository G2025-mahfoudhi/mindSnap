class Conversation < ApplicationRecord
  belongs_to :user
  has_many :messages, dependent: :destroy

  # Contexte optionnel : peut être liée à un Folder (chat contextuel Phase 4)
  belongs_to :context, polymorphic: true, optional: true

  validates :name, presence: true

  # Conversations générales (non liées à un document ou dossier)
  scope :general, -> { where(context_type: nil) }

  def folder_scoped?
    context_type == "Folder" && context_id.present?
  end
end
