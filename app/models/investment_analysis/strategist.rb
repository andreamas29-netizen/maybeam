# Combines the horizon agents' research into one structured recommendation per holding
class InvestmentAnalysis::Strategist
  def initialize(portfolio:, agent_reports:, provider:, investor: {})
    @portfolio = portfolio
    @agent_reports = agent_reports
    @provider = provider
    @investor = investor
  end

  def recommend
    response = provider.structured_response(prompt: prompt, instructions: instructions, schema: schema)
    raise response.error unless response.success?

    response.data
  end

  private
    attr_reader :portfolio, :agent_reports, :provider, :investor

    def instructions
      <<~PROMPT
        You are the portfolio strategist on an investment research team. Three analysts have studied a
        private investor's holdings, each for a different time horizon. Turn their research into a clear
        recommendation for every holding and every horizon.

        Actions:
        - add: increase the position
        - hold: keep the position as it is
        - trim: reduce the position, for example to lower concentration or lock in gains
        - sell: exit the position

        Act like a personal advisor who knows this investor: fit every action to their risk profile, goals and
        notes when they are given, and say how to use any uninvested cash.

        Base each action on the matching analyst's research and the investor's actual position. Horizons can
        disagree; that is expected and useful. Keep each rationale to two or three plain sentences that a
        non-expert can follow. Pick conviction honestly: low when the evidence is thin or mixed.

        In the summary, give the investor a short Markdown overview: overall portfolio health, the most
        important actions to consider, and concentration or diversification issues.

        This output is informational and educational. It is not licensed or personalized financial advice,
        so do not promise returns.
      PROMPT
    end

    def prompt
      reports = InvestmentAnalysis::Agent::HORIZONS.map do |horizon, config|
        "## #{config[:label]} analyst (#{config[:window]})\n\n#{agent_reports.dig(horizon, "report")}"
      end

      <<~PROMPT
        Investor profile, as JSON:

        #{JSON.pretty_generate(investor)}

        Holdings, as JSON:

        #{JSON.pretty_generate(portfolio)}

        # Analyst research

        #{reports.join("\n\n")}
      PROMPT
    end

    def schema
      horizon_view = {
        type: "object",
        properties: {
          action: { type: "string", enum: InvestmentAnalysis::ACTIONS },
          rationale: { type: "string" }
        },
        required: %w[action rationale],
        additionalProperties: false
      }

      {
        type: "object",
        properties: {
          summary: { type: "string" },
          recommendations: {
            type: "array",
            items: {
              type: "object",
              properties: {
                ticker: { type: "string" },
                name: { type: "string" },
                short_term: horizon_view,
                medium_term: horizon_view,
                long_term: horizon_view,
                conviction: { type: "string", enum: %w[low medium high] },
                key_risks: { type: "string" }
              },
              required: %w[ticker name short_term medium_term long_term conviction key_risks],
              additionalProperties: false
            }
          }
        },
        required: %w[summary recommendations],
        additionalProperties: false
      }
    end
end
