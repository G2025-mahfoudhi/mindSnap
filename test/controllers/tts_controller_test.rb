require "test_helper"

class TtsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:test_user1)
    sign_in @user
  end

  test "text vide retourne bad_request" do
    post tts_speak_path, params: { text: "" }
    assert_response :bad_request
  end

  test "text manquant retourne bad_request" do
    post tts_speak_path, params: {}
    assert_response :bad_request
  end

  test "text trop long retourne bad_request" do
    post tts_speak_path, params: { text: "a" * 5000 }
    assert_response :bad_request
  end

  test "redirige vers login si pas connecté" do
    sign_out @user
    post tts_speak_path, params: { text: "Hello" }
    assert_redirected_to new_user_session_path
  end
end
