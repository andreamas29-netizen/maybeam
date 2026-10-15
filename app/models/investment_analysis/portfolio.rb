# Snapshot of a family's current security holdings, aggregated by ticker across investment accounts,
# in the shape the analysis agents receive.
class InvestmentAnalysis::Portfolio
  def initialize(family)
    @family = family
  end

  def holdings_data
    grouped = current_holdings.group_by(&:security)
    total_value = grouped.values.flatten.sum { |h| value_in_family_currency(h) }

    grouped.map do |security, holdings|
      value = holdings.sum { |h| value_in_family_currency(h) }
      qty = holdings.sum(&:qty)
      cost_basis = holdings.sum { |h| h.qty * h.avg_cost.amount }
      market_value = holdings.sum(&:amount)

      {
        "ticker" => security.ticker,
        "name" => security.name.presence || security.ticker,
        "isin" => isin?(security.ticker) ? security.ticker : nil,
        "exchange_mic" => security.exchange_operating_mic,
        "country_code" => security.country_code,
        "quantity" => qty.to_f,
        "price" => holdings.first.price.to_f,
        "price_date" => holdings.first.date.iso8601,
        "currency" => holdings.first.currency,
        "market_value" => market_value.to_f.round(2),
        "portfolio_weight_pct" => total_value.zero? ? 0 : (value / total_value * 100).to_f.round(2),
        "average_cost" => qty.zero? ? nil : (cost_basis / qty).to_f.round(4),
        "unrealized_return_pct" => cost_basis.zero? ? nil : ((market_value - cost_basis) / cost_basis * 100).to_f.round(2),
        "accounts" => holdings.map { |h| h.account.name }.uniq
      }
    end.sort_by { |h| -h["portfolio_weight_pct"] }
  end

  # Uninvested cash sitting in the investment accounts, in the family currency
  def cash_balance
    investment_accounts.sum do |account|
      Money.new(account.cash_balance || 0, account.currency).exchange_to(family.currency, fallback_rate: 1).amount
    end.to_f.round(2)
  end

  # What the agents should know about the investor beyond their holdings
  def investor_profile
    {
      "base_currency" => family.currency,
      "uninvested_cash" => cash_balance,
      "risk_profile" => Family::INVESTOR_RISK_PROFILES[family.investor_risk_profile],
      "goals_and_notes" => family.investor_notes.presence
    }.compact
  end

  private
    attr_reader :family

    ISIN_FORMAT = /\A[A-Z]{2}[A-Z0-9]{9}\d\z/

    def isin?(value)
      ISIN_FORMAT.match?(value.to_s)
    end

    def investment_accounts
      family.accounts.visible.where(accountable_type: "Investment")
    end

    def current_holdings
      investment_accounts
        .includes(:accountable)
        .flat_map { |account| account.current_holdings.includes(:security, :account).to_a }
    end

    def value_in_family_currency(holding)
      holding.amount_money.exchange_to(family.currency, fallback_rate: 1).amount
    end
end
