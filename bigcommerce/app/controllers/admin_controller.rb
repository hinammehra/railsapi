require 'csv_import.rb'
require 'csv_generator.rb'
require 'stock_control.rb'

class AdminController < ApplicationController
    before_action :confirm_logged_in

    include CsvGenerator
    include StockControl
    include DatesHelper

    # CustType
    # CustGroup
    # CustStore
    # Staff

    # Address - scrape - Shipping Address
    # Coupon - scrape - also from inside order

    # def initialize
    #   @update_time = nil
    #   @start_time = nil

    # end

    def index;end

    # def scrape

    #   Revision.new.insert

    #   models_scrape = [Category.new, Product.new, Customer.new, Status.new, Order.new]

    #   models_scrape.each do |m|
    #     m.scrape
    #   end

    #   csv_import

    #   @success = "Yay!"

    # end

    def update; end

    def update_products
        Product.new.update_from_api(Revision.bigcommerce.update_time_iso)
    end

    def update_customers
        Customer.new.update_from_api(Revision.bigcommerce.update_time_iso)
    end

    def update_orders
        BigcommerceOrder.new.update_from_api(Revision.bigcommerce.update_time_iso)
    end

    def import_from_csv
        # product_files = [[ProducerCountry, "producer_countries", nil], [Producer, "producers", nil],\
        # [ProducerRegion, "producer_regions", nil], [ProductType, "product_types", nil],\
        # [ProductSubType, "product_sub_types", nil], [ProductSize, "product_sizes", nil],\
        # [ProductPackageType, "product_package_types", nil],[Warehouse, "warehouses", nil]]

        # product_files.each do |p|

        # CSVImport.new.do(Product, "products" , "current", "display")
        # CSVImport.new.do(ProducerRegion, 'producer_regions')
        # CSVImport.new.do(ProductSubType, 'product_subtype')
        # CSVImport.new.do(Producer, 'producers')
        # CSVImport.new.do(ProductNoWs, 'Prod_no_ws')
        # CSVImport.new.do(ProductNoVintage, 'product_novintage')
        # CSVImport.new.do(Product, 'products')
        # CSVImport.new.do(Order, 'OrderAdjustPleaseWill')
        # CSVImport.new.do(Customer, 'customers')

        # end

        # render 'update'
    end

    # models_csv_import = [CustGroup.new, CustStyle.new, CustType.new, Customer.new]

    # models_scrape.each do |m|
    # m.csv_import
    # end

    def xero_sync
      begin
        if params[:commit].to_s.include?'Xero'
          start_time = Time.now.utc
          Revision.xero.update_end_time
          xero = XeroController.new
          xero.update_xero_contacts
          xero.update_xero_invoices

          system 'rake xero_invoice_sync:sync'
          flash[:success] = 'Xero Sync Successed!'
          Revision.xero.end_update(start_time, Time.now)
        else
          Revision.bigcommerce.start_update
    			start_time = Time.now
          admin = AdminController.new
          admin.update_customers
          admin.update_products
          admin.update_orders
          xero = XeroController.new
          xero.update_xero_contacts
          xero.update_xero_invoices
          Revision.bigcommerce.end_update(start_time, Time.now)

          flash[:success] = 'Sync Successed!'
        end
      rescue Exception => ex
        ReminderMailer.error_warning(ex.class, ex.message, ex.backtrace).deliver_now
      end

      redirect_to request.referrer
    end

    def password_update
        current_user = Staff.find(session[:user_id])
        if current_user.can_update
            if params[:staff].present? && params[:staff][:id].present?
                staff_to_update = Staff.find(params[:staff][:id])
                if params[:new_password].eql? params[:new_password_confirmation]
                    staff_to_update.password_digest = BCrypt::Password.create(params[:new_password])
                    staff_to_update.save!
                    flash[:success] = 'Updated'
                else
                    flash[:error] = 'Passwords don\'t match'
                end
            else
                flash[:error] = 'Select a Staff to Update'
            end
        else
            flash[:error] = 'Not authorised to update'
        end
        redirect_to action: 'index'
    end

    def admin;end

    def password_update_user
      current_user = Staff.find(session[:user_id])
      if current_user.can_update
          if params[:staff].present? && params[:staff][:id].present?
              staff_to_update = Staff.find(params[:staff][:id])
              if params[:new_password].eql? params[:new_password_confirmation]
                  staff_to_update.password_digest = BCrypt::Password.create(params[:new_password])
                  staff_to_update.save!
                  flash[:success] = 'Updated'
              else
                  flash[:error] = 'Passwords don\'t match'
              end
          else
              flash[:error] = 'Select a Staff to Update'
          end
      else
          flash[:error] = 'Not authorised to update'
      end
      redirect_to action: 'admin'
    end

    def staff_order_update
      redirect_to action: 'index'
    end

    def download_csv
      case params[:commit]
      when 'Customer'
        send_data export_customer(Date.parse(params[:date][:start_date]), Date.parse(params[:date][:end_date])), filename: "customer-#{Date.parse(params[:date][:end_date])}.csv" and return
      when 'Order Products'
        send_data export_order_products(Date.parse(params[:date][:start_date]), Date.parse(params[:date][:end_date])), filename: "order-products-#{Date.parse(params[:date][:end_date])}.csv" and return
      when 'Orders'
        send_data export_orders(params[:status],Date.parse(params[:date][:start_date]), Date.parse(params[:date][:end_date])), filename: "orders-#{Date.parse(params[:date][:end_date])}.csv" and return
      when 'Shipment'
        send_data export_shipment(Date.parse(params[:date][:start_date]), Date.parse(params[:date][:end_date])), filename: "ship-#{Date.parse(params[:date][:end_date])}.csv" and return
      when 'ScotPac'
        redirect_to action: 'scotpac' and return
        # send_data export_orders(12, (Date.today - 8.years), Date.today), filename: "ScotPac-#{Date.parse(params[:date][:end_date])}.csv" and return
      end
      redirect_to :back
    end

    def export_stock_control
      @countries = ProducerCountry.product_country
      # Include Only In Stock Products
      # Function in lib stock control
      @product_hash = stock_calculation()

      @portfolio_list = portfolio_products()

      respond_to do |format|
        format.html
        format.xlsx {
          response.headers['Content-Disposition'] = "attachment; filename=Stock Control #{Date.today.to_s}.xlsx"
        }
      end
    end

    def export_sale_report

      end_date = Date.today
      selected_period = "weekly"
      num_periods = 13

      group_staffs = {
        :gavin => [10],
        :mat => [54, 50, 5],
        :amy => [55, 44, 35]
      }

      # periods_from_end_date is defined in Dates Helper
      # returns an array of all dates - sorted
      # For example num_periods = 3, end_date = 20th oct and "monthly" as period_type returns
      # {
      #   23=>[Mon, 04 Jun 2018, Mon, 11 Jun 2018], 
      #   24=>[Mon, 11 Jun 2018, Mon, 18 Jun 2018], 
      #   25=>[Mon, 18 Jun 2018, Wed, 20 Jun 2018]
      # }
      # 20th Oct is the last date in the array and not 19th oct because
      # we want to calculate orders including 19th Oct, for that we need to give the next day
      dates = periods_from_end_date(num_periods, end_date, selected_period)

      # returns a hash like {week_num/month_num => [start_date, end_date]}
      # i.e. { 20=>[Mon, 14 May 2018, Mon, 21 May 2018] }
      dates_paired = pair_dates(dates, selected_period)

      # should return - group_by_week_created
      group_by_function = (period_date_functions(selected_period)[2] + "_and_customer_id").to_sym

      sum_orders = Order.date_filter(dates[0], dates[-1]).valid_order.customer_staffs_filter(group_staffs[:gavin]).send(group_by_function).sum_total
      # @staff_sum_by_periods = sum_orders(@dates[0], @dates[-1], (date_function + group_by_date_function_staff).to_sym, sum_function, staff_id)
      # def sum_orders(start_date, end_date, group_by_date_function, sum_function, staff_id)
      # return Order.date_filter(start_date, end_date).valid_order.customer_staff_filter(staff_id).send(group_by_date_function).send(sum_function)

      render xlsx: "export_sale_report", filename: "Sale Report #{Date.today.to_s}.xlsx"
      # respond_to do |format|
      #   # format.xlsx
      #   format.html
      #   format.xlsx {
      #     response.headers['Content-Disposition'] = "attachment; filename=Sale Report #{Date.today.to_s}.xlsx"
      #   }
      # end


      logger.info "exporting sale report ..."
    end

    def scotpac_export
      @orders = Order.where(id: params[:selected_orders])
      respond_to do |format|
        format.html
        format.xlsx {
          response.headers['Content-Disposition'] = "attachment; filename=Scot Pac #{Date.today.to_s}.xlsx"
        }
      end
    end

    def scotpac
      @manual_verify = excel_order(12, (Date.today - 8.years), Date.today)
      @cust_ref = excel_customer((Date.today - 8.years), Date.today)
      @contacts = excel_receivables()
      @shipping = excel_shipping((Date.today - 1.month), Date.today)

      respond_to do |format|
        format.html
        format.xlsx {
          response.headers['Content-Disposition'] = "attachment; filename=Scot Pac #{Date.today.to_s}.xlsx"
        }
      end
    end

    def group_list
      group_creation(params) unless params[:staff_group].nil?
      default_group_update(params) unless params[:default_group].nil?

      params = {}
      @groups = StaffGroup.staff_groups(session[:user_id])
    end

    def group_creation(params)
      if params[:staff_group][:group_name].to_s == ""
        flash[:error] = 'Group must have a name!'
      elsif StaffGroup.duplicated(session[:user_id], params[:staff_group][:group_name]).blank?
        StaffGroup.new({group_name: params[:staff_group][:group_name], staff_id: session[:user_id]}).save
        flash[:success] = 'Group Created!'
      else
        flash[:error] = 'Duplicated Group Name!'
      end
    end

    def default_group_update(params)
      session[:default_group] = params[:default_group]
    end

    def fetch_group_detail
      @group = StaffGroup.where(id: params[:group_id]).first
      respond_to do |format|
        format.js
      end
    end

    def fetch_add_item
      StaffGroupItem.new(staff_group_id: params[:group_id], item_model: params[:item_model], item_id: params[:item_id]).save
      respond_to do |format|
        format.js
      end
    end

    def fetch_remove_item
      StaffGroupItem.where(staff_group_id: params[:group_id], item_model: params[:item_model], item_id: params[:item_id]).delete_all
      respond_to do |format|
        format.js
      end
    end
end
