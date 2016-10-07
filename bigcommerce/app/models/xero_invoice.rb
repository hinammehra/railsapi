require 'xero_connection.rb'
require 'clean_data.rb'

class XeroInvoice < ActiveRecord::Base

	include CleanData

	self.primary_key = 'xero_invoice_id'

	has_one :order
	belongs_to :xero_contact
	has_many :xero_invoice_line_items
	has_many :xero_payments

	has_many :xero_cn_allocations
	has_many :xero_op_allocations

	def scrape

		xero = XeroConnection.new.connect

  		page_num = 1
		
		invoices = xero.Invoice.all(page: page_num)

		until invoices.blank?

			invoices.each do |i|

				date = map_date(i.date)
	  			due_date = map_date(i.due_date)
	  			updated_date = map_date(i.updated_date_utc)
	  			fully_paid_on_date = map_date(i.fully_paid_on_date)
	  			expected_payment_date = map_date(i.expected_payment_date)

	  	 		contact_name = remove_apostrophe(i.contact_name) unless i.contact_name.nil?

	  			
	  			time = Time.now.to_s(:db)

	  			if valid_invoice(i) && invoice_doesnt_exist(i.invoice_id)

		  			sql = "INSERT INTO xero_invoices (xero_invoice_id, invoice_number,\
		  			xero_contact_id, contact_name, sub_total, total_tax, total, total_discount,\
		  			amount_due, amount_paid, amount_credited, date, due_date, fully_paid_on_date,\
		  			expected_payment_date, updated_date, status, line_amount_types, type, reference,\
		  			currency_code, currency_rate, url, reference, branding_theme_id, sent_to_contact,\
		  			has_attachments, created_at, updated_at)\
		  			VALUES ('#{i.invoice_id}', '#{i.invoice_number}',\
		  			'#{i.contact_id}', '#{contact_name}', '#{i.sub_total(true)}', '#{i.total_tax(true)}',\
		  			'#{i.total(true)}', '#{i.total_discount}', '#{i.amount_due}', '#{i.amount_paid}',\
		  			'#{i.amount_credited}', '#{date}', '#{due_date}', '#{fully_paid_on_date}',\
		  			'#{expected_payment_date}', '#{updated_date}', '#{i.status}', '#{i.line_amount_types}',\
		  			'#{i.type}', '#{i.reference}', '#{i.currency_code}', '#{i.currency_rate}',\
		  			'#{i.url}', '#{i.reference}', '#{i.branding_theme_id}', '#{i.sent_to_contact}',\
		  			'#{i.has_attachments}', '#{time}', '#{time}')"

		  			ActiveRecord::Base.connection.execute(sql)

		  			XeroInvoiceLineItem.new.scrape(i.line_items, i.invoice_id)
		  		end
	  		end

	  		page_num += 1

	  		invoices = xero.Invoice.all(page: page_num)

  		end

	end

	def valid_invoice(invoice)
		if invoice.status != 'DELETED' && invoice.type == 'ACCREC'
			return true
	    else
	    	return false
	    end
	end

	def invoice_doesnt_exist(invoice_id)
        if XeroInvoice.where(xero_invoice_id: invoice_id).count == 0
  			return true
  		else
  			return false
  	    end
  	end

end
