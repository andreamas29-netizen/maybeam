class InvestmentAnalysisSchedulesController < ApplicationController
  def update
    Current.family.update!(weekly_investment_analysis: params[:weekly] == "1")

    redirect_to investment_analyses_path
  end
end
