require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = users(:test_user1)
  end

  test "valide avec email et password" do
    user = User.new(email: "new@test.com", password: "password123", first_name: "Test", last_name: "User")
    assert user.valid?
  end

  test "invalide sans email" do
    user = User.new(password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email].map(&:downcase).join, "blank"
  end

  test "invalide sans password" do
    user = User.new(email: "new@test.com")
    assert_not user.valid?
  end

  test "email unique" do
    User.create!(email: "unique@test.com", password: "password123")
    duplicate = User.new(email: "unique@test.com", password: "password123")
    assert_not duplicate.valid?
  end

  test "a des documents" do
    assert_respond_to @user, :documents
  end

  test "a des dossiers" do
    assert_respond_to @user, :folders
  end

  test "a des conversations" do
    assert_respond_to @user, :conversations
  end

  test "a des tags" do
    assert_respond_to @user, :tags
  end

  test "a des messages via conversations" do
    assert_respond_to @user, :messages
  end

  test "destroy cascade sur documents" do
    doc = @user.documents.create!(title: "Cascade test", document_type: "Note")
    assert_equal 1, @user.documents.count
    @user.destroy
    assert_equal 0, Document.where(id: doc.id).count
  end
end
