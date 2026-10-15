require "test_helper"

class InvestmentAnalysis::PortfolioTest < ActiveSupport::TestCase
  test "summarizes current holdings with weights" do
    data = InvestmentAnalysis::Portfolio.new(families(:dylan_family)).holdings_data

    assert_equal 1, data.size

    aapl = data.first
    assert_equal "AAPL", aapl["ticker"]
    assert_equal 10.0, aapl["quantity"]
    assert_equal 2150.0, aapl["market_value"]
    assert_equal 100.0, aapl["portfolio_weight_pct"]
    assert_equal [ "Robinhood Brokerage Account" ], aapl["accounts"]
  end

  test "is empty for a family without investments" do
    assert_empty InvestmentAnalysis::Portfolio.new(families(:empty)).holdings_data
  end

  test "describes the investor for the agents" do
    family = families(:dylan_family)
    family.update!(investor_risk_profile: "balanced", investor_notes: "Saving for a house")

    profile = InvestmentAnalysis::Portfolio.new(family).investor_profile

    assert_equal family.currency, profile["base_currency"]
    assert_match "Balanced", profile["risk_profile"]
    assert_equal "Saving for a house", profile["goals_and_notes"]
    assert profile.key?("uninvested_cash")
  end
end
