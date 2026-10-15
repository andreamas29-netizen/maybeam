# Imports the "Transaction export" CSV from the Trade Republic app
# (Profile > Statements/Documents > Transaction export).
#
# The file has a fixed layout, so no column mapping is needed:
# rows with shares become trades, every other row with a cash amount becomes a cash transaction
# (deposits, withdrawals, dividends, interest, card spending, fees). Securities are keyed by ISIN.
class TradeRepublicImport < Import
  DEFAULT_ACCOUNT_NAME = "Trade Republic".freeze

  REQUIRED_HEADERS = %w[date category type name symbol shares price amount currency].freeze

  after_create :set_mappings

  def self.trade_republic_csv?(csv_str)
    headers = parse_csv_str(csv_str).headers.compact.map(&:downcase)
    (REQUIRED_HEADERS - headers).empty?
  rescue CSV::MalformedCSVError
    false
  end

  def generate_rows_from_csv
    rows.destroy_all

    mapped_rows = csv_rows.filter_map do |row|
      cash = cash_impact(row)
      qty = row["shares"].to_s.strip
      trade = qty.present? && qty.to_d != 0 && row["symbol"].present?

      # Skip informational rows that neither move shares nor cash
      next if !trade && cash.zero?

      {
        account: DEFAULT_ACCOUNT_NAME,
        date: row["date"].to_s,
        qty: trade ? qty : "",
        ticker: trade ? row["symbol"].to_s.strip.upcase : "",
        exchange_operating_mic: "",
        price: trade ? row["price"].to_s : "",
        amount: cash.to_s("F"),
        currency: row["currency"].presence || default_currency,
        name: row_name(row, trade),
        category: "",
        tags: "",
        entity_type: row["type"].to_s,
        notes: row["description"].to_s
      }
    end

    rows.insert_all!(mapped_rows) if mapped_rows.any?
  end

  def import!
    transaction do
      target = account || find_or_create_account!

      rows.each do |row|
        entry = if row.qty.present?
          security = find_or_create_security(row.ticker, row.name)

          target.entries.build(
            date: row.date_iso,
            # Trade entries are positive for cash leaving the account (buys)
            amount: -row.amount.to_d,
            name: row.name,
            currency: row.currency,
            entryable: Trade.new(security: security, qty: row.qty.to_d, price: row.price.to_d, currency: row.currency),
            import: self
          )
        else
          target.entries.build(
            date: row.date_iso,
            # Transaction entries are positive for outflows; Trade Republic writes inflows as positive
            amount: -row.amount.to_d,
            name: row.name,
            currency: row.currency,
            notes: row.notes.presence,
            entryable: Transaction.new(kind: transfer_type?(row.entity_type) ? "funds_movement" : "standard"),
            import: self
          )
        end

        entry.save!
      end
    end
  end

  def required_column_keys
    %i[date]
  end

  def column_keys
    %i[date ticker qty price amount currency name]
  end

  def mapping_steps
    []
  end

  def dry_run
    { transactions: rows.count }
  end

  def csv_template
    template = <<~CSV
      "datetime","date","account_type","category","type","asset_class","name","symbol","shares","price","amount","fee","tax","currency","original_amount","original_currency","fx_rate","description","transaction_id","counterparty_name","counterparty_iban","payment_reference","mcc_code"
      "2026-01-02T09:00:00.000Z","2026-01-02","DEFAULT","CASH","CUSTOMER_INBOUND","","","","","","1000.00","","","EUR","","","","","1","","","",""
      "2026-01-05T07:30:00.000Z","2026-01-05","DEFAULT","TRADING","SAVINGS_PLAN_EXECUTED","FUND","Core MSCI World USD (Acc)","IE00B4L5Y983","1.2345","101.23","-124.97","0.00","","EUR","","","","","2","","","",""
      "2026-03-10T14:05:12.000Z","2026-03-10","DEFAULT","TRADING","BUY","STOCK","Apple","US0378331005","2","180.50","-361.00","-1.00","","EUR","","","","","3","","","",""
    CSV

    CSV.parse(template, headers: true)
  end

  private
    TRANSFER_TYPES = %w[
      CUSTOMER_INBOUND CUSTOMER_INPAYMENT CUSTOMER_OUTBOUND_REQUEST
      TRANSFER_INSTANT_INBOUND TRANSFER_INSTANT_OUTBOUND TRANSFER_INBOUND TRANSFER_OUTBOUND
    ].freeze

    def set_mappings
      self.date_col_label = "date"
      self.date_format = "%Y-%m-%d"
      self.number_format = "1,234.56"
      self.signage_convention = "inflows_positive"
      self.ticker_col_label = "symbol"
      self.qty_col_label = "shares"
      self.price_col_label = "price"
      self.amount_col_label = "amount"
      self.currency_col_label = "currency"
      self.name_col_label = "name"
      self.entity_type_col_label = "type"
      self.notes_col_label = "description"

      save!
    end

    # Net effect on the cash balance, positive when cash comes in
    def cash_impact(row)
      %w[amount fee tax].sum { |col| parse_decimal(row[col]) }
    end

    def parse_decimal(value)
      value.to_s.strip.presence&.to_d || 0.to_d
    rescue ArgumentError
      0.to_d
    end

    def row_name(row, trade)
      label = row["type"].to_s.humanize.presence || "Trade Republic"
      subject = row["name"].presence || row["counterparty_name"].presence || row["description"].presence

      return label if subject.blank?
      trade ? "#{label}: #{subject}" : "#{label} - #{subject}"
    end

    def transfer_type?(type)
      TRANSFER_TYPES.include?(type)
    end

    def find_or_create_account!
      family.accounts.find_by(name: DEFAULT_ACCOUNT_NAME, accountable_type: "Investment") ||
        family.accounts.create!(
          name: DEFAULT_ACCOUNT_NAME,
          balance: 0,
          cash_balance: 0,
          currency: rows.first&.currency || family.currency,
          accountable: Investment.new,
          import: self
        )
    end

    # Trade Republic identifies securities by ISIN. Without a market data provider the
    # security is created offline, named after the export so the agents can research it.
    def find_or_create_security(isin, row_name)
      @security_cache ||= {}
      @security_cache[isin] ||= begin
        security = Security::Resolver.new(isin).resolve
        security_name = row_name.to_s.split(": ", 2).last
        security.update!(name: security_name) if security.name.blank? && security_name.present?
        security
      end
    end
end
