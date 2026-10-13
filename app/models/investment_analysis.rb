# A point-in-time study of a family's stock and ETF holdings, produced by a team of AI agents.
#
# Three horizon agents (short, medium and long term) research the holdings in parallel with live
# web search, then a strategist agent turns their reports into one recommendation per holding.
#
# Output is informational only and is not licensed financial advice.
class InvestmentAnalysis < ApplicationRecord
  Error = Class.new(StandardError)

  ACTIONS = %w[add hold trim sell].freeze

  belongs_to :family

  enum :status, {
    pending: "pending",
    running: "running",
    completed: "completed",
    failed: "failed"
  }, default: :pending, validate: true

  enum :trigger, { manual: "manual", scheduled: "scheduled" }, default: :manual, validate: true, prefix: :triggered

  scope :ordered, -> { order(created_at: :desc) }
  scope :in_progress, -> { where(status: %w[pending running]) }

  broadcasts_refreshes

  class << self
    def provider
      Provider::Registry.get_provider(:anthropic)
    end

    def available?
      provider.present?
    end
  end

  def run_later
    InvestmentAnalysisJob.perform_later(self)
  end

  def run
    provider = self.class.provider
    raise Error, "No AI provider is configured. Add an Anthropic API key in Settings." unless provider

    holdings = Portfolio.new(family).holdings_data
    raise Error, "There are no stock or ETF holdings to analyze yet." if holdings.empty?

    update!(status: :running, model: provider.model, portfolio: holdings)

    reports = Agent.run_all(portfolio: holdings, currency: family.currency, provider: provider)
    update!(agent_reports: reports)

    result = Strategist.new(portfolio: holdings, agent_reports: reports, provider: provider).recommend

    update!(
      status: :completed,
      summary: result["summary"],
      recommendations: result["recommendations"],
      completed_at: Time.current
    )
  rescue => e
    Rails.logger.error("Investment analysis #{id} failed: #{e.message}")
    Sentry.capture_exception(e) unless e.is_a?(Error)
    update!(status: :failed, error: e.message)
  end

  def in_progress?
    (pending? || running?) && created_at > 1.hour.ago
  end

  def recommendation_for(ticker)
    recommendations.find { |r| r["ticker"] == ticker }
  end

  def agent_report(horizon)
    agent_reports[horizon.to_s] || {}
  end
end
