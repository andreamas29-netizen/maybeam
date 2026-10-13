class InvestmentAnalysesController < ApplicationController
  before_action { @breadcrumbs = [ [ "Home", root_path ], [ "Insights", nil ] ] }

  def index
    @analyses = Current.family.investment_analyses.ordered.limit(10)
    @analysis = @analyses.first
  end

  def show
    @analysis = Current.family.investment_analyses.find(params[:id])
  end

  def create
    unless InvestmentAnalysis.available?
      redirect_to investment_analyses_path, alert: "Add an Anthropic API key in Settings to run an analysis."
      return
    end

    analysis = Current.family.analyze_investments_later
    redirect_to investment_analysis_path(analysis)
  end
end
