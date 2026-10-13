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
end
