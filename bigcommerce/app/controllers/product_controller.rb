# filter products based on paramaters
require 'models_filter.rb'

# provide stats for no vintage products, no ws products
require 'product_variations.rb'

# to calculate overall stats and top customers
require 'time_period_stats.rb'

# for calendar period types for overall stats - weekly, monthly, quarterly
require 'dates_helper.rb'

class ProductController < ApplicationController

	before_action :confirm_logged_in

	include ModelsFilter
  	include ProductVariations
  	include TimePeriodStats
  	include DatesHelper

  	def all
	    filtered_products = filter(params)
	    transform(params)

	    # check the number of queries - make it faster
	    @stock_h, @price_h, @pending_stock_h, products_transformed = \
	    all_products_transform(@transform_column, filtered_products)
	    
	    display_(params, products_transformed)
  	end

  	# Displays Overall Stats and Top Customers for Product
  	def summary
  		params_for_one_product(params)
  		transform(params)
  		# either we want stats for a product_id or for products based on a product_no_vintage_id
    	# or based on a product_no_ws_id
    	# this gives product_ids based on that transform_column
    	product_ids = transform_product_ids(@transform_column, @product_id) || @product_id

    	# overall_stats has structure {time_period_name => [sum, average, supply]}
    	@overall_stats = overall(params, product_ids, 0)

    	# top customers
  	end

  	def overall(params, product_ids, total_stock)
  		# period type for overall stats - monthly or weekly
   		@selected_period, @period_types = define_period_types(params)
   		@result = overall_stats("Order.product_filter(%s).valid_order" % \
   			[product_ids], :sum_order_product_qty, @selected_period, total_stock)
  	end

  	def top_customers(params, product_ids)
  		# form filter for top customers
  		# 25 is passed instead of staff_id
  		# because we haven't implemented Product Display Rights yet. 
  		@staff, customers_filtered, @search_text, staff_id, @cust_style = customer_param_filter(params, 25)
  		staff_id = staff_id.nil? ? "nil" : staff_id

  		# result_h has the form {time_period_name => {customer_id => stock_bought}}
  		@result_h, @customer_ids, @time_periods, already_sorted = \
  		top_objects("Order.product_filter(%s).valid_order.staff_filter(%s)" % \
  			[product_ids, staff_id], :group_by_customerid, :sum_order_product_qty,\
  			params[:order_col], params[:direction])

  	end

  	def params_for_one_product(params)
  		@product_id = params[:product_id]
    	@product_name = params[:product_name]
  	end

  	def filter(params)
  		@producer_country, @product_sub_type, products, @search_text = product_param_filter(params)
  		return products
  	end

  	def transform(params)
  		@transform_column = params[:transform_column] || "product_id"
	    @checked_id, @checked_no_vintage, @checked_no_ws = checked_radio_button(@transform_column)
	end

	def display_(params, products)
		# sorting by every table col doesn't work
	    order_function, direction = sort_order(params, 'order_by_name', 'ASC')
	    
	    @per_page = params[:per_page] || Product.per_page
	    @products = products.send(order_function, direction).paginate( per_page: @per_page, page: params[:page])
	end


end