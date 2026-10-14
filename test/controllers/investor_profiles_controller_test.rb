require "test_helper"

class InvestorProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
  end

  test "saves the investor profile" do
    patch investor_profile_path, params: { family: { investor_risk_profile: "growth", investor_notes: "Retirement in 30 years" } }

    assert_redirected_to investment_analyses_path
    family = @user.family.reload
    assert_equal "growth", family.investor_risk_profile
    assert_equal "Retirement in 30 years", family.investor_notes
  end

  test "rejects an unknown risk profile" do
    patch investor_profile_path, params: { family: { investor_risk_profile: "yolo" } }

    assert_redirected_to investment_analyses_path
    assert_nil @user.family.reload.investor_risk_profile
  end
end
