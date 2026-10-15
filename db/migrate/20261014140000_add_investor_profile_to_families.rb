class AddInvestorProfileToFamilies < ActiveRecord::Migration[7.2]
  def change
    add_column :families, :investor_risk_profile, :string
    add_column :families, :investor_notes, :text
  end
end
