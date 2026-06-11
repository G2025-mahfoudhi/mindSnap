require "test_helper"

class TaggingTest < ActiveSupport::TestCase
  setup do
    @user = users(:test_user1)
    @tag = Tag.create!(name: "test-tag", user: @user)
    @document = Document.create!(
      user: @user,
      title: "Tagged doc",
      content: "x",
      document_type: "Note"
    )
  end

  test "lie un tag à un document" do
    tagging = Tagging.create!(tag: @tag, taggable: @document)
    assert_equal @tag, tagging.tag
    assert_equal @document, tagging.taggable
    assert_equal "Document", tagging.taggable_type
  end

  test "un document peut avoir plusieurs tags" do
    tag2 = Tag.create!(name: "second-tag", user: @user)
    Tagging.create!(tag: @tag, taggable: @document)
    Tagging.create!(tag: tag2, taggable: @document)
    assert_equal 2, @document.taggings.count
    assert_equal 2, @document.tags.count
  end

  test "tag-taggable unique (contrainte DB)" do
    Tagging.create!(tag: @tag, taggable: @document)
    assert_raises(ActiveRecord::RecordNotUnique) do
      Tagging.create!(tag: @tag, taggable: @document)
    end
  end
end
