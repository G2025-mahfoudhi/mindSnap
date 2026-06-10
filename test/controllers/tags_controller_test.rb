require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:test_user1)
    @tag = @user.tags.create!(name: "important")
  end

  test "redirige vers login si pas connecté" do
    patch tag_path(@tag), params: { tag: { name: "test" } }
    assert_redirected_to new_user_session_path
  end

  test "rename tag" do
    sign_in @user
    patch tag_path(@tag), params: { tag: { name: "urgent" } }
    assert_redirected_to settings_path(tab: :tags)
    @tag.reload
    assert_equal "urgent", @tag.name
  end

  test "rename tag normalise le nom" do
    sign_in @user
    patch tag_path(@tag), params: { tag: { name: "  URGENT  " } }
    @tag.reload
    assert_equal "urgent", @tag.name
  end

  test "rename tag with invalid name" do
    sign_in @user
    patch tag_path(@tag), params: { tag: { name: "" } }
    assert_redirected_to settings_path(tab: :tags)
    assert_equal "important", @tag.reload.name
  end

  test "destroy tag" do
    sign_in @user
    assert_difference("Tag.count", -1) do
      delete tag_path(@tag)
    end
    assert_redirected_to settings_path(tab: :tags)
  end

  test "cannot access another user tag" do
    other = User.create!(email: "other@test.com", password: "password123", first_name: "Other", last_name: "User")
    other_tag = other.tags.create!(name: "secret")

    sign_in @user
    delete tag_path(other_tag)
    assert_response :not_found
  end
end
