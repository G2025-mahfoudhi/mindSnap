require "test_helper"

class FolderTest < ActiveSupport::TestCase
  setup do
    @user = users(:test_user1)
  end

  test "valide avec nom et user" do
    folder = Folder.new(name: "Mon dossier", user: @user)
    assert folder.valid?
  end

  test "nom par défaut si non fourni" do
    folder = Folder.new(user: @user)
    folder.valid?
    assert_equal "Nouveau dossier", folder.name
  end

  test "nom par défaut si vide" do
    folder = Folder.create!(user: @user)
    assert_equal "Nouveau dossier", folder.name
  end

  test "appartient à un user" do
    folder = Folder.create!(name: "Test", user: @user)
    assert_equal @user, folder.user
  end

  test "peut avoir un parent" do
    parent = Folder.create!(name: "Parent", user: @user)
    child = Folder.create!(name: "Enfant", user: @user, parent: parent)
    assert_equal parent, child.parent
    assert_includes parent.children, child
  end

  test "parent optionnel" do
    folder = Folder.create!(name: "Racine", user: @user)
    assert_nil folder.parent
  end

  test "a des documents" do
    folder = Folder.create!(name: "Avec docs", user: @user)
    doc = @user.documents.create!(title: "Doc", document_type: "Note", folder: folder)
    assert_includes folder.documents, doc
  end

  test "destroy cascade sur enfants" do
    parent = Folder.create!(name: "Parent", user: @user)
    child = Folder.create!(name: "Enfant", user: @user, parent: parent)
    parent.destroy
    assert_equal 0, Folder.where(id: child.id).count
  end

  test "destroy cascade sur documents" do
    folder = Folder.create!(name: "Avec docs", user: @user)
    doc = @user.documents.create!(title: "Doc", document_type: "Note", folder: folder)
    folder.destroy
    assert_equal 0, Document.where(id: doc.id).count
  end
end
