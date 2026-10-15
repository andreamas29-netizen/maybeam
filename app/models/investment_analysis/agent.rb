# A research agent that studies the portfolio through the lens of a single time horizon.
# It has live web search, so it works from current prices, news, filings and analyst coverage.
class InvestmentAnalysis::Agent
  HORIZONS = {
    "short_term" => {
      label: "Short term",
      window: "the next 1 to 3 months",
      focus: <<~FOCUS
        - Recent price action, momentum and volatility versus the broader market
        - Upcoming catalysts in the window: earnings dates, product events, ex-dividend dates, index rebalances
        - Material news from the last few weeks and how the market reacted
        - Macro events in the window that matter for these holdings (central bank meetings, inflation data)
      FOCUS
    },
    "medium_term" => {
      label: "Medium term",
      window: "the next 3 to 18 months",
      focus: <<~FOCUS
        - Earnings and revenue trajectory, guidance and analyst estimate revisions
        - Valuation versus history and peers (P/E, EV/EBITDA, free cash flow yield)
        - Sector and business cycle positioning
        - For ETFs: sector and factor exposure, recent flows and how the underlying index is positioned for the cycle
      FOCUS
    },
    "long_term" => {
      label: "Long term",
      window: "3 or more years",
      focus: <<~FOCUS
        - Business quality: competitive moat, margins, return on capital, balance sheet strength
        - Secular trends that help or hurt the business over years
        - Management, capital allocation and dilution
        - For ETFs: expense ratio, tracking, diversification and index methodology
        - Portfolio construction: concentration, overlap between holdings and diversification gaps
      FOCUS
    }
  }.freeze

  class << self
    # Runs one agent per horizon in parallel and returns their reports keyed by horizon
    def run_all(portfolio:, currency:, provider:, investor: {})
      futures = HORIZONS.keys.map do |horizon|
        agent = new(horizon, portfolio: portfolio, currency: currency, provider: provider, investor: investor)
        Concurrent::Promises.future { [ horizon, agent.research ] }
      end

      Concurrent::Promises.zip(*futures).wait

      # Re-raises the first agent's error, if any
      futures.map(&:value!).to_h
    end
  end

  def initialize(horizon, portfolio:, currency:, provider:, investor: {})
    @horizon = horizon
    @portfolio = portfolio
    @currency = currency
    @provider = provider
    @investor = investor
  end

  def research
    response = provider.research(prompt: prompt, instructions: instructions)
    raise response.error unless response.success?

    {
      "report" => response.data.text,
      "sources" => response.data.sources.map { |s| { "title" => s.title, "url" => s.url } }
    }
  end

  private
    attr_reader :horizon, :portfolio, :currency, :provider, :investor

    def config
      HORIZONS.fetch(horizon)
    end

    def instructions
      <<~PROMPT
        You are the #{config[:label].downcase} analyst on an investment research team. You study a
        private investor's stock and ETF holdings for #{config[:window]} and write a research note
        that a portfolio strategist will use to make recommendations.

        Today's date is #{Date.current.iso8601}. Use web search to get current prices, news, filings and
        analyst coverage. Do not rely on memory for anything time sensitive, and say when data could not be found.
        The price in the holdings data is the last price the app knows (see price_date) and can be stale, so
        look up the current price. Some holdings are identified only by ISIN and name; use them to find the security.

        Tailor your view to the investor's profile when one is given: their risk tolerance, goals and time
        horizon, and their uninvested cash.

        Focus on:
        #{config[:focus]}
        For every holding, write a short section with the evidence you found and your view for
        #{config[:window]}: whether the setup looks favorable, neutral or unfavorable, and why. Weigh the
        investor's actual position: its weight in the portfolio and their unrealized gain or loss.
        End with a few sentences on the portfolio as a whole for this horizon.

        Be balanced and specific, cite numbers with dates, and name the key risks. Write in Markdown.
        This research is informational and is not personalized financial advice.
      PROMPT
    end

    def prompt
      <<~PROMPT
        The investor's base currency is #{currency}. Their profile, as JSON:

        #{JSON.pretty_generate(investor)}

        Their current holdings, as JSON:

        #{JSON.pretty_generate(portfolio)}
      PROMPT
    end
end
