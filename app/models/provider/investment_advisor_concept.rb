module Provider::InvestmentAdvisorConcept
  extend ActiveSupport::Concern

  Source = Data.define(:title, :url)
  ResearchReport = Data.define(:text, :sources)

  # Open-ended research with live web access. Returns a ResearchReport.
  def research(prompt:, instructions:)
    raise NotImplementedError, "Subclasses must implement #research"
  end

  # Returns a Hash that conforms to the given JSON schema
  def structured_response(prompt:, instructions:, schema:)
    raise NotImplementedError, "Subclasses must implement #structured_response"
  end
end
