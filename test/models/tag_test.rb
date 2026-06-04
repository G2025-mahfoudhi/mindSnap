require "test_helper"

class TagTest < ActiveSupport::TestCase
  setup do
    @user = users(:test_user1)
  end

  test "valide avec nom et user" do
    tag = Tag.new(name: "machine-learning", user: @user)
    assert tag.valid?
  end

  test "invalide sans nom" do
    tag = Tag.new(user: @user)
    assert_not tag.valid?
  end

  test "normalise le nom en minuscules" do
    tag = Tag.create!(name: "  Machine Learning  ", user: @user)
    assert_equal "machine learning", tag.name
  end

  test "nom unique par utilisateur" do
    Tag.create!(name: "ruby", user: @user)
    duplicate = Tag.new(name: "Ruby", user: @user)
    assert_not duplicate.valid?
  end

  test "même nom autorisé pour utilisateurs différents" do
    other = User.create!(
      email: "other@test.com",
      password: "password123",
      first_name: "Other"
    )
    Tag.create!(name: "rails", user: @user)
    tag = Tag.new(name: "rails", user: other)
    assert tag.valid?
  end

  test "a des taggings" do
    tag = Tag.create!(name: "test-tag", user: @user)
    assert_respond_to tag, :taggings
  end
end
