class InvestmentAnalysisJob < ApplicationJob
  queue_as :medium_priority

  def perform(investment_analysis)
    investment_analysis.run
  end
end
