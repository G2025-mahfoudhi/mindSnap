# Tag généré automatiquement par l'IA pour catégoriser les documents.
# Chaque utilisateur a ses propres tags (scope par user_id).
# Les tags sont normalisés en minuscules et sans espaces superflus.
class Tag < ApplicationRecord
  belongs_to :user
  has_many :taggings, dependent: :destroy

  validates :name, presence: true,
                   uniqueness: { scope: :user_id, case_sensitive: false }

  before_save { self.name = name.downcase.strip }
end
