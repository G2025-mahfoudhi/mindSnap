require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:test_user1)
  end

  test "redirige vers login si pas connecté" do
    get settings_path
    assert_redirected_to new_user_session_path
  end

  test "get show" do
    sign_in @user
    get settings_path
    assert_response :success
  end

  test "get show with tab parameter" do
    sign_in @user
    get settings_path(tab: :tags)
    assert_response :success
  end

  test "update preferences" do
    sign_in @user
    patch settings_path, params: {
      user: {
        preferred_language: "en",
        summary_length: "detailed",
        auto_tagging: false,
        tts_voice: "af_heart",
        default_view: "list"
      }
    }
    assert_redirected_to settings_path(tab: :preferences)
    @user.reload
    assert_equal "en", @user.preferred_language
    assert_equal "detailed", @user.summary_length
    assert_equal false, @user.auto_tagging
    assert_equal "af_heart", @user.tts_voice
    assert_equal "list", @user.default_view
  end

  test "update profile" do
    sign_in @user
    patch settings_path, params: {
      user: {
        _tab: "profile",
        first_name: "Jean",
        last_name: "Dupont"
      }
    }
    assert_redirected_to settings_path(tab: :profile)
    @user.reload
    assert_equal "Jean", @user.first_name
    assert_equal "Dupont", @user.last_name
  end

  test "default preferences values" do
    sign_in @user
    get settings_path
    assert_equal "fr", @user.preferred_language
    assert_equal "medium", @user.summary_length
    assert_equal true, @user.auto_tagging
    assert_equal "ff_siwis", @user.tts_voice
    assert_equal "grid", @user.default_view
  end

  test "clear history" do
    sign_in @user
    @user.conversations.create!(name: "Conv 1")
    @user.conversations.create!(name: "Conv 2")
    assert_equal 2, @user.conversations.count

    delete clear_history_settings_path
    assert_redirected_to settings_path(tab: :data)
    assert_equal 0, @user.conversations.reload.count
  end

  test "export JSON" do
    sign_in @user
    doc = @user.documents.create!(title: "Test doc", content: "Contenu test", document_type: "note")
    post export_settings_path, params: { export_format: "json" }
    assert_response :success
    assert_equal "application/json", response.content_type

    json = JSON.parse(response.body)
    assert_equal @user.email, json["user"]["email"]
    assert_equal 1, json["documents"].size
    assert_equal "Test doc", json["documents"].first["title"]
  end

  test "export invalid format" do
    sign_in @user
    post export_settings_path, params: { export_format: "invalid" }
    assert_redirected_to settings_path(tab: :data)
  end
end
