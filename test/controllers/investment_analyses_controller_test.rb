require "test_helper"

class InvestmentAnalysesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @analysis = investment_analyses(:completed)
  end

  test "index shows the latest analysis" do
    get investment_analyses_path

    assert_response :success
    assert_select "p", text: "AAPL"
    assert_match "not licensed or personalized financial advice", response.body
  end

  test "show" do
    get investment_analysis_path(@analysis)

    assert_response :success
    assert_match "Too concentrated.", response.body
  end

  test "create starts an analysis" do
    Provider::Registry.stubs(:get_provider).with(:anthropic).returns(mock)
    InvestmentAnalysisJob.expects(:perform_later).once

    assert_difference "InvestmentAnalysis.count", 1 do
      post investment_analyses_path
    end

    assert_redirected_to investment_analysis_path(InvestmentAnalysis.ordered.first)
  end

  test "create requires a provider" do
    Provider::Registry.stubs(:get_provider).with(:anthropic).returns(nil)

    assert_no_difference "InvestmentAnalysis.count" do
      post investment_analyses_path
    end

    assert_redirected_to investment_analyses_path
  end

  test "toggles the weekly schedule" do
    patch investment_analysis_schedule_path, params: { weekly: "1" }

    assert @user.family.reload.weekly_investment_analysis?
  end
end
