class ScheduledInvestmentAnalysisJob < ApplicationJob
  queue_as :scheduled

  def perform
    return unless InvestmentAnalysis.available?

    Family.where(weekly_investment_analysis: true).find_each do |family|
      family.analyze_investments_later(trigger: :scheduled)
    end
  end
end
