require 'bigcommerce_connection.rb'
require 'clean_data.rb'

class Order < ActiveRecord::Base
	belongs_to :customer

	belongs_to :status

	belongs_to :coupon

	belongs_to :staff

	has_many :order_shippings
	has_many :addresses, through: :order_shippings

	belongs_to :billing_address, class_name: :Address, foreign_key: :billing_address_id

	has_many :order_products
	has_many :products, through: :order_products

	belongs_to :order_history

	def scrape

		order_api = Bigcommerce::Order
		order_count = order_api.count.count
		limit = 50 
		order_pages = (order_count/limit) + 1
		
		page_number = 1

		order_product = OrderProduct.new
		
		order_pages.times do

			orders = order_api.all(page: page_number)

			orders.each do |o|
				
				insert_or_update(o, 1)
				order_product.insert(o.id)

			end

			page_number += 1

		end

	end

	def update_from_api(update_time)

		order_api = Bigcommerce::Order

		order_count = order_api.count(min_date_modified: update_time).count
		limit = 50
		order_pages = (order_count/limit) + 1
		order_product = OrderProduct.new

		page_number = 1

		order_pages.times do

			orders = order_api.all(min_date_modified: update_time, page: page_number)
			
			if orders.blank?
				return
			end

			orders.each do |o|
				if !Order.where(id: o.id).blank?
					#move row to history, update this one

					# Insert into Order History tables
					#last_insert_id = OrderHistory.new.insert(o.id)
					#OrderProductHistory.new.insert(last_insert_id, o.id)

					# Update Order Table
					insert_or_update(o, 0)
					

				    # doing a delete - insert instead of a select - update
				    # because select - update doesnt work when product gets deleted

				    # Update Order Product table
				    order_product.delete(o.id)
				    order_product.insert(o.id)

				else
					#insert a new one
					insert_or_update(o, 1)
					order_product.insert(o.id)
				end

			end

			page_number += 1
		end

	end

	def insert_or_update(o, insert)

		order = sql = ""
		time = Time.now.to_s(:db)

		clean = CleanData.new
		date_created = clean.map_date(o.date_created)
		date_modified = clean.map_date(o.date_modified)
		date_shipped = clean.map_date(o.date_shipped)

		staff_notes = clean.remove_apostrophe(o.staff_notes)

		customer_notes = clean.remove_apostrophe(o.customer_message)

		active = clean.convert_bool(o.is_deleted)

		payment_method = clean.remove_apostrophe(o.payment_method)

		if insert == 1

			order = "('#{o.id}', '#{o.customer_id}', '#{date_created}', '#{date_modified}',\
			'#{date_shipped}', '#{o.status_id}', '#{o.subtotal_ex_tax}', '#{o.subtotal_inc_tax}',\
			'#{o.subtotal_tax}', '#{o.base_shipping_cost}', '#{o.shipping_cost_ex_tax}', '#{o.shipping_cost_inc_tax}',\
			'#{o.shipping_cost_tax}', '#{o.shipping_cost_tax_class_id}', '#{o.base_handling_cost}',\
			'#{o.handling_cost_ex_tax}', '#{o.handling_cost_inc_tax}', '#{o.handling_cost_tax}',\
			'#{o.handling_cost_tax_class_id}', '#{o.base_wrapping_cost}', '#{o.wrapping_cost_ex_tax}',\
			'#{o.wrapping_cost_inc_tax}', '#{o.wrapping_cost_tax}', '#{o.wrapping_cost_tax_class_id}',\
			'#{o.total_ex_tax}', '#{o.total_inc_tax}', '#{o.total_tax}', '#{o.items_total}', '#{o.items_shipped}',\
			'#{o.refunded_amount}', '#{o.store_credit_amount}', '#{o.gift_certificate_amount}',\
			'#{o.ip_address}', '#{staff_notes}', '#{customer_notes}',\
			'#{o.discount_amount}', '#{o.coupon_discount}', '#{active}', '#{o.order_source}', '#{time}', '#{time}', '#{payment_method}')"

			
			sql = "INSERT INTO orders (id, customer_id, date_created, date_modified, date_shipped,\
			status_id, subtotal_ex_tax, subtotal_inc_tax, subtotal_tax, base_shipping_cost,\
			shipping_cost_ex_tax, shipping_cost_inc_tax, shipping_cost_tax, shipping_cost_tax_class_id,\
			base_handling_cost, handling_cost_ex_tax, handling_cost_inc_tax, handling_cost_tax, handling_cost_tax_class_id,\
			base_wrapping_cost, wrapping_cost_ex_tax, wrapping_cost_inc_tax, wrapping_cost_tax, wrapping_cost_tax_class_id,\
			total_ex_tax, total_inc_tax, total_tax, qty, items_shipped, refunded_amount, store_credit,\
			gift_certificate_amount, ip_address, staff_notes, customer_notes, discount_amount,\
			coupon_discount, active, order_source, created_at, updated_at, payment_method)\
			VALUES #{order}"

		else
			sql = "UPDATE orders SET customer_id = '#{o.customer_id}', date_created = '#{date_created}',\
					date_modified = '#{date_modified}', date_shipped = '#{date_shipped}', status_id = '#{o.status_id}',\
					subtotal_ex_tax = '#{o.subtotal_ex_tax}', subtotal_inc_tax = '#{o.subtotal_inc_tax}', subtotal_tax = '#{o.subtotal_tax}', base_shipping_cost = '#{o.base_shipping_cost}',\
					shipping_cost_ex_tax = '#{o.shipping_cost_ex_tax}', shipping_cost_inc_tax = '#{o.shipping_cost_inc_tax}', shipping_cost_tax = '#{o.shipping_cost_tax}',\
					shipping_cost_tax_class_id = '#{o.shipping_cost_tax_class_id}', base_handling_cost = '#{o.base_handling_cost}', handling_cost_ex_tax = '#{o.handling_cost_ex_tax}',\
					handling_cost_inc_tax = '#{o.handling_cost_inc_tax}', handling_cost_tax = '#{o.handling_cost_tax}', handling_cost_tax_class_id = '#{o.handling_cost_tax_class_id}',\
					total_ex_tax = '#{o.total_ex_tax}', total_inc_tax = '#{o.total_inc_tax}', total_tax = '#{o.total_tax}', qty = '#{o.items_total}', items_shipped = '#{o.items_shipped}',\
					refunded_amount = '#{o.refunded_amount}', store_credit = '#{o.store_credit_amount}', gift_certificate_amount = '#{o.gift_certificate_amount}',\
					ip_address = '#{o.ip_address}', staff_notes = '#{staff_notes}', customer_notes = '#{customer_notes}', discount_amount = '#{o.discount_amount}',\
					coupon_discount = '#{o.coupon_discount}', active = '#{active}', order_source = '#{o.order_source}', updated_at = '#{time}', payment_method = '#{o.payment_method}' WHERE id = '#{o.id}'"

		end
		ActiveRecord::Base.connection.execute(sql)

	end
	
end