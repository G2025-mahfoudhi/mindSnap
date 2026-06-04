require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  test "home accessible sans auth" do
    get root_path
    assert_response :success
  end

  test "home accessible quand connecté" do
    sign_in users(:test_user1)
    get root_path
    assert_response :success
  end
end
