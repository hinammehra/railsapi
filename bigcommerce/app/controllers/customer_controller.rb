require 'time_period_stats.rb'
require 'product_variations.rb'
require 'models_filter.rb'
require 'dates_helper.rb'

class CustomerController < ApplicationController

	before_action :confirm_logged_in

	include TimePeriodStats
	include ProductVariations
	include ModelsFilter
  include DatesHelper

  def all
    @staffs = Staff.active_sales_staff
    customers = filter(params, "display_report")
    display_(params, customers)
  end

  def incomplete_customers
    customers_filtered = filter(params, "display_report")
    display_(params, customers_filtered.incomplete)
    render 'all'
  end

  # Orders and Overall Stats for Customer
  def summary
    get_id_and_name(params)
    # overall_stats has structure {time_period_name => [sum, average, supply]}
    @overall_stats = overall_stats_(params)
    display_orders(params, Order.customer_filter([@customer_id]))
  end

  def summary_with_product
    get_id_and_name(params)
    @product_id = params[:product_id]
    @product_name = params[:product_name]
    @transform_column = params[:transform_column]

    # either we want stats for a product_id or for products based on a product_no_vintage_id
    # or based on a product_no_ws_id
    # this gives product_ids based on that transform_column
    @product_ids = transform_product_ids(@transform_column, @product_id) || [@product_id]

    # overall_stats has structure {time_period_name => [sum, average, supply]}
    @overall_stats = overall_stats_with_product(params, @product_ids)
    display_orders(params, Order.customer_filter([@customer_id]).product_filter(@product_ids))
  end

  def overall_stats_(params)
    @selected_period, @period_types = define_period_types(params)
    @result = overall_stats("Order.customer_filter(%s).valid_order" % \
        [[@customer_id]], :sum_total, @selected_period, nil)
  end

  def overall_stats_with_product(params, product_ids)
    @selected_period, @period_types = define_period_types(params)
    @result = overall_stats("Order.customer_filter(%s).order_product_filter(%s).valid_order" % \
        [[@customer_id], product_ids], :sum_order_product_qty, @selected_period, nil)
  end

  def display_orders(params, orders)
    order_function, direction = sort_order(params, :order_by_id, 'DESC')
    @per_page = params[:per_page] || Order.per_page
    @orders = orders.include_all.send(order_function, direction).paginate( per_page: @per_page, page: params[:page])
  end

  def get_id_and_name(params)
    @customer_id = params[:customer_id]
    @customer_name = params[:customer_name]
  end

  def filter(params, rights_col)
    @staff, customers, @search_text, staff_id, @cust_style = customer_filter(params, session[:user_id], rights_col)
    return customers
  end

  def display_(params, customers)
    order_function, direction = sort_order(params, 'order_by_name', 'ASC')

    @per_page = params[:per_page] || Customer.per_page
    @customers = customers.include_all.send(order_function, direction).paginate( per_page: @per_page, page: params[:page])
  end

  def edit
    get_id_and_name(params)
    # params[:customer][:id] is used since update is a post request
    # once you update using post request, then want to update again, we need to use params[:customer][:id]
    @customer = Customer.include_all.filter_by_id(@customer_id || params[:customer][:id])
  end

  def update
    @customer = Customer.filter_by_id(params[:customer][:id])
    if @customer.update_attributes(customer_params)
      flash[:success] = "Successfully Changed."
      redirect_to action: 'summary',\
       customer_id: params[:customer][:id],\
       customer_name: Customer.customer_name(@customer.actual_name, @customer.firstname, @customer.lastname)
    else
      flash[:error] = "Unsuccessful."
      render 'edit'
    end
  end

  def update_staff
    customer_id = params[:customer_id]
    staff_id = params[:staff_id]

    Customer.staff_change(staff_id, customer_id)

    #render html: "#{customer_id}, #{staff_id}".html_safe
    flash[:success] = "Staff Successfully Changed."
    redirect_to request.referrer

  end

	# Displays Stats for all the products the customer has ordered
	def top_products
  	get_id_and_name(params)

  	# filter products based on params
  	@producer_country, @product_sub_type, products, @search_text = product_filter(params)

  	# which view of products needs to be displayed - normal products, or no vintage products, etc.
		@transform_column = params[:transform_column] || "product_no_vintage_id"
  	@checked_id, @checked_no_vintage, @checked_no_ws = checked_radio_button(@transform_column)

  	# Get top products
  	# To get top products, get all the orders for a customer, then get products of those orders
  	# based on the above param filters, filter products out
  	where_query = "OrderProduct.valid_orders.order_customer_filter(%s).product_filter(%s)" % [[@customer_id], Product.all.pluck("id")]

		# hash has a structure {"time_period" => {product_id => stock}}
		# product_ids can be either product ids or even
		# product no vintage ids
		# group_by can be group_by_product_id, group_by_product_no_vintage_id
		@top_products_timeperiod_h, @product_ids, @time_periods, sorted_bool = \
		top_objects(where_query, ('group_by_' + @transform_column).to_sym, :sum_qty, params[:order_col], params[:direction])

		@price_h, @product_name_h = top_products_transform(@transform_column, @product_ids)

    # Sort by name/price
    ####################################
    # PUT THIS IN A LIB
    unless sorted_bool
      sort_column_map = {"0" => @product_name_h, "1" => @price_h}
      # @name_h or @price_h are the structure {id => val}
      # sort the hash using the val, then get the product_ids in order using map
      hash_to_be_sorted = sort_column_map[params[:order_col]] || @product_name_h
      sorted_hash = hash_to_be_sorted.sort_by {|id, val| val}

      if params[:direction].to_i == 1
        @product_ids = sorted_hash.map {|product| product[0]}
      else
        @product_ids = sorted_hash.reverse.map {|product| product[0]}
      end
    end
    ####################################
	end

  private

  def customer_params
    params.require(:customer).permit(:firstname, :lastname, :actual_name, :staff_id, :cust_style_id,\
      :cust_group_id)
  end

end
