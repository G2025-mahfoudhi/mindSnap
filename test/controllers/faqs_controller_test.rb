require "test_helper"

class FaqsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  test "faq accessible sans auth" do
    get faq_path
    assert_response :success
  end

  test "faq accessible quand connecté" do
    sign_in users(:test_user1)
    get faq_path
    assert_response :success
  end
end
