class CreateInvestmentAnalyses < ActiveRecord::Migration[7.2]
  def change
    create_table :investment_analyses, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.string :status, null: false, default: "pending"
      t.string :trigger, null: false, default: "manual"
      t.string :model
      t.jsonb :portfolio, null: false, default: []
      t.jsonb :agent_reports, null: false, default: {}
      t.text :summary
      t.jsonb :recommendations, null: false, default: []
      t.text :error
      t.datetime :completed_at

      t.timestamps
    end

    add_column :families, :weekly_investment_analysis, :boolean, null: false, default: false
  end
end
