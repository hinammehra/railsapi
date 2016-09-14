module ApplicationHelper

  def title(page_title)
  	content_for(:title) { page_title }
  end

  def display_num(value)
	number_with_delimiter(number_with_precision(value, precision: 2))
  end

  def date_format(date)
  	date.to_date.strftime('%A %d/%m/%y')
  end

  def date_format_orders(date)
    date.to_date.strftime('%d/%m/%y')
  end

  def customer_name(customer)
  	Customer.customer_name(customer.actual_name, customer.firstname, customer.lastname) unless customer.nil?
  end

  def order_status(status)
  	status.name
  end

  def staff_nickname(customer)
  	customer.staff.nickname unless customer.nil?
  end

  def paginate(model)
    will_paginate model unless model.count < 15
  end

end
