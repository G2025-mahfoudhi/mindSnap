# Jointure polymorphique entre un tag et une ressource taggable (Document).
# L'unicité tag+taggable est garantie par une contrainte d'index DB.
class Tagging < ApplicationRecord
  belongs_to :tag
  belongs_to :taggable, polymorphic: true

  after_destroy :cleanup_orphan_tag

  private

  def cleanup_orphan_tag
    tag.destroy if tag.taggings.count.zero?
  end
end
