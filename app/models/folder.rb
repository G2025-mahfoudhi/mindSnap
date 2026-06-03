class Folder < ApplicationRecord
  belongs_to :user
  belongs_to :parent,
             class_name: "Folder",
             foreign_key: "parent_id",
             optional: true

  has_many :children,
           class_name: "Folder",
           foreign_key: "parent_id",
           dependent: :destroy

  has_many :documents, dependent: :destroy

  before_validation :set_default_name

  validates :name, presence: true

  private

  def set_default_name
    self.name = "Nouveau dossier" if name.blank?
  end
end
