class InvestorProfilesController < ApplicationController
  def update
    if Current.family.update(investor_profile_params)
      redirect_to investment_analyses_path, notice: "Your investor profile was saved. The next analysis will use it."
    else
      redirect_to investment_analyses_path, alert: Current.family.errors.full_messages.to_sentence
    end
  end

  private
    def investor_profile_params
      params.require(:family).permit(:investor_risk_profile, :investor_notes)
    end
end
