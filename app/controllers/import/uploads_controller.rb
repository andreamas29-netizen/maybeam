class Import::UploadsController < ApplicationController
  layout "imports"

  before_action :set_import

  def show
  end

  def sample_csv
    send_data @import.csv_template.to_csv,
      filename: "#{@import.type.underscore.split('_').first}_sample.csv",
      type: "text/csv",
      disposition: "attachment"
  end

  def update
    if @import.is_a?(TradeRepublicImport) && !TradeRepublicImport.trade_republic_csv?(csv_str)
      flash.now[:alert] = "This doesn't look like a Trade Republic transaction export. Upload the CSV from Documents > Transaction export in the Trade Republic app."

      render :show, status: :unprocessable_entity
    elsif csv_valid?(csv_str)
      @import.account = Current.family.accounts.find_by(id: params.dig(:import, :account_id))
      @import.assign_attributes(raw_file_str: csv_str, col_sep: upload_params[:col_sep])
      @import.save!(validate: false)

      if @import.is_a?(TradeRepublicImport)
        # The export has a fixed layout, so it skips the configuration step
        @import.generate_rows_from_csv
        redirect_to import_clean_path(@import), notice: "Trade Republic export uploaded successfully."
      else
        redirect_to import_configuration_path(@import, template_hint: true), notice: "CSV uploaded successfully."
      end
    else
      flash.now[:alert] = "Must be valid CSV with headers and at least one row of data"

      render :show, status: :unprocessable_entity
    end
  end

  private
    def set_import
      @import = Current.family.imports.find(params[:import_id])
    end

    def csv_str
      @csv_str ||= upload_params[:csv_file]&.read || upload_params[:raw_file_str]
    end

    def csv_valid?(str)
      begin
        csv = Import.parse_csv_str(str, col_sep: upload_params[:col_sep])
        return false if csv.headers.empty?
        return false if csv.count == 0
        true
      rescue CSV::MalformedCSVError
        false
      end
    end

    def upload_params
      params.require(:import).permit(:raw_file_str, :csv_file, :col_sep)
    end
end
