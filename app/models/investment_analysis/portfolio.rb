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
        "exchange_mic" => security.exchange_operating_mic,
        "country_code" => security.country_code,
        "quantity" => qty.to_f,
        "price" => holdings.first.price.to_f,
        "currency" => holdings.first.currency,
        "market_value" => market_value.to_f.round(2),
        "portfolio_weight_pct" => total_value.zero? ? 0 : (value / total_value * 100).to_f.round(2),
        "average_cost" => qty.zero? ? nil : (cost_basis / qty).to_f.round(4),
        "unrealized_return_pct" => cost_basis.zero? ? nil : ((market_value - cost_basis) / cost_basis * 100).to_f.round(2),
        "accounts" => holdings.map { |h| h.account.name }.uniq
      }
    end.sort_by { |h| -h["portfolio_weight_pct"] }
  end

  private
    attr_reader :family

    def current_holdings
      family.accounts
        .visible
        .where(accountable_type: "Investment")
        .includes(:accountable)
        .flat_map { |account| account.current_holdings.includes(:security, :account).to_a }
    end

    def value_in_family_currency(holding)
      holding.amount_money.exchange_to(family.currency, fallback_rate: 1).amount
    end
end
