require "test_helper"

class TradeRepublicImportTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper, ImportInterfaceTest

  setup do
    @subject = imports(:trade_republic)
    @family = families(:dylan_family)
    @csv = file_fixture("trade_republic_export.csv").read
    Security.stubs(:provider).returns(nil)

    @import = @family.imports.create!(type: "TradeRepublicImport", date_format: @family.date_format)
    @import.update!(raw_file_str: @csv)
  end

  test "recognizes a Trade Republic export" do
    assert TradeRepublicImport.trade_republic_csv?(@csv)
    assert_not TradeRepublicImport.trade_republic_csv?("date,ticker,qty,price\n01/01/2024,AAPL,1,100")
  end

  test "generates trade and cash rows, skipping rows without shares or cash" do
    @import.generate_rows_from_csv

    rows = @import.rows.ordered
    assert_equal 8, rows.count
    assert rows.all?(&:valid?)

    buy = rows.find { |r| r.entity_type == "BUY" }
    assert_equal "NL0011585146", buy.ticker
    assert_equal "3", buy.qty
    assert_equal "-1201.0", buy.amount # includes the fee

    dividend = rows.find { |r| r.entity_type == "DIVIDEND" }
    assert dividend.qty.blank?
    assert_equal "6.5", dividend.amount # net of tax
  end

  test "imports into a new Trade Republic investment account with holdings by ISIN" do
    @import.generate_rows_from_csv
    @import.reload

    assert_difference -> { Account.count } => 1,
                      -> { Trade.count } => 4,
                      -> { Transaction.count } => 4 do
      @import.publish
    end

    assert @import.reload.complete?

    account = @family.accounts.find_by!(name: "Trade Republic")
    assert account.investment?

    ferrari = Security.find_by!(ticker: "NL0011585146")
    assert_equal "Ferrari", ferrari.name
    assert ferrari.offline?

    ferrari_trades = account.trades.where(security: ferrari)
    assert_equal 2, ferrari_trades.sum(:qty)

    sell = account.entries.joins("JOIN trades ON trades.id = entries.entryable_id").find_by(trades: { qty: -1 })
    assert_equal(-419, sell.amount) # proceeds after the fee are an inflow

    deposit = account.entries.find_by!(name: "Customer inbound - Jane Doe")
    assert_equal(-2000, deposit.amount)
    assert deposit.entryable.funds_movement?
  end

  test "imports into a chosen account" do
    target = accounts(:investment)
    @import.update!(account: target)
    @import.generate_rows_from_csv
    @import.reload

    assert_no_difference -> { Account.count } do
      @import.publish
    end

    assert_equal 8, target.entries.where(import: @import).count
  end
end
