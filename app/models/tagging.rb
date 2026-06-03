# Jointure polymorphique entre un tag et une ressource taggable (Document).
# L'unicité tag+taggable est garantie par une contrainte d'index DB.
class Tagging < ApplicationRecord
  belongs_to :tag
  belongs_to :taggable, polymorphic: true
end
