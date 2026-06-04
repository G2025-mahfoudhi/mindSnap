require "test_helper"

class TranscriptionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:test_user1)
    sign_in @user
  end

  test "audio_base64 manquant retourne bad_request" do
    post transcribe_path, params: {}
    assert_response :bad_request
  end

  test "audio_base64 vide retourne bad_request" do
    post transcribe_path, params: { audio_base64: "" }
    assert_response :bad_request
  end

  test "redirige vers login si pas connecté" do
    sign_out @user
    post transcribe_path, params: { audio_base64: "dGVzdA==" }
    assert_redirected_to new_user_session_path
  end
end
