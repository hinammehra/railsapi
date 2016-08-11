class OrderHistory < ActiveRecord::Base
	has_many :orders

	belongs_to :customer

	belongs_to :status

	belongs_to :coupon

	belongs_to :staff

	has_many :order_shipping_histories
	has_many :addresses, through: :order_shipping_histories

	belongs_to :billing_address, class_name: :Address, foreign_key: :billing_address_id

	has_many :order_product_histories
	has_many :products, through: :order_product_histories

	def insert(order_id)

		insert = "INSERT INTO order_histories SELECT NULL, orders.* FROM orders WHERE id = '#{order_id}'"

		last_insert_id = ActiveRecord::Base.connection.insert(insert)

		return last_insert_id
	

	end
end
