class Tag < ApplicationRecord
  belongs_to :user
  has_many :taggings, dependent: :destroy

  validates :name, presence: true,
            uniqueness: { scope: :user_id, case_sensitive: false }

  before_save { self.name = name.downcase.strip }
end
