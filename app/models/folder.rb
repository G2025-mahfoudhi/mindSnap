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

  validates :name, presence: true
end