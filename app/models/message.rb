class Message < ApplicationRecord
  belongs_to :conversation

  validates :content, presence: true, unless: :streaming?
  validates :role, presence: true
end
