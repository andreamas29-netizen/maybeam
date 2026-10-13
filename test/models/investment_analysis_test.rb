require "test_helper"

class InvestmentAnalysisTest < ActiveSupport::TestCase
  include ProviderTestHelper

  setup do
    @family = families(:dylan_family)
    @provider = mock
    @provider.stubs(:model).returns("claude-opus-5-5")
    Provider::Registry.stubs(:get_provider).with(:anthropic).returns(@provider)
  end

  test "agents research each horizon and the strategist produces recommendations" do
    @provider.expects(:research).times(3).returns(
      provider_success_response(Provider::InvestmentAdvisorConcept::ResearchReport.new(
        text: "AAPL looks fine.",
        sources: [ Provider::InvestmentAdvisorConcept::Source.new(title: "News", url: "https://example.com") ]
      ))
    )

    @provider.expects(:structured_response).with do |prompt:, instructions:, schema:|
      prompt.include?("AAPL looks fine.") && schema[:required] == %w[summary recommendations]
    end.returns(provider_success_response({
      "summary" => "All good.",
      "recommendations" => [ { "ticker" => "AAPL", "short_term" => { "action" => "hold", "rationale" => "Steady." } } ]
    }))

    analysis = @family.investment_analyses.create!
    analysis.run

    assert analysis.completed?
    assert_equal "claude-opus-5-5", analysis.model
    assert_equal "AAPL", analysis.portfolio.first["ticker"]
    assert_equal %w[long_term medium_term short_term], analysis.agent_reports.keys.sort
    assert_equal "https://example.com", analysis.agent_report(:short_term)["sources"].first["url"]
    assert_equal "All good.", analysis.summary
    assert_equal "hold", analysis.recommendation_for("AAPL").dig("short_term", "action")
  end

  test "fails when an agent errors" do
    @provider.stubs(:research).returns(provider_error_response(Provider::Anthropic::Error.new("overloaded")))
    @provider.expects(:structured_response).never

    analysis = @family.investment_analyses.create!
    analysis.run

    assert analysis.failed?
    assert_equal "overloaded", analysis.error
  end

  test "fails without a configured provider" do
    Provider::Registry.stubs(:get_provider).with(:anthropic).returns(nil)

    analysis = @family.investment_analyses.create!
    analysis.run

    assert analysis.failed?
    assert_match "Anthropic API key", analysis.error
  end

  test "family does not start a second analysis while one is in progress" do
    InvestmentAnalysisJob.expects(:perform_later).once

    first = @family.analyze_investments_later

    assert_no_difference "InvestmentAnalysis.count" do
      assert_equal first, @family.analyze_investments_later
    end
  end
end
