require 'xero_connection.rb'
require 'clean_data.rb'
require 'dates_helper.rb'

class XeroInvoice < ActiveRecord::Base
    include CleanData
    include DatesHelper

    self.primary_key = 'xero_invoice_id'

    belongs_to :order, foreign_key: :invoice_number
    belongs_to :xero_contact
    has_many :xero_invoice_line_items
    has_many :xero_payments

    has_many :xero_cn_allocations
    has_many :xero_op_allocations

    def download_data_from_api(modified_since_time)
        xero = XeroConnection.new.connect

        page_num = 1

        invoices = xero.Invoice.all(page: page_num, modified_since: modified_since_time)

        until invoices.blank?

            invoices.each do |i|
                date = map_date(i.date)
                due_date = map_date(i.due_date)
                updated_date = map_date(i.updated_date_utc)
                fully_paid_on_date = map_date(i.fully_paid_on_date)
                expected_payment_date = map_date(i.expected_payment_date)

                contact_name = remove_apostrophe(i.contact_name)
                url = remove_apostrophe(i.url)
                reference = remove_apostrophe(i.reference)

                sent_to_contact = convert_bool(i.sent_to_contact)
                has_attachments = convert_bool(i.has_attachments)

                calculate_line_amount = line_amount_types == 'Inclusive' ? true : false

                time = Time.now.to_s(:db)

                next unless valid_invoice(i)

                if invoice_doesnt_exist(i.invoice_id)

                    sql = "INSERT INTO xero_invoices (xero_invoice_id, invoice_number,\
      						xero_contact_id, contact_name, sub_total, total_tax, total, total_discount,\
      						amount_due, amount_paid, amount_credited, date, due_date, fully_paid_on_date,\
      						expected_payment_date, updated_date, status, line_amount_types, invoice_type,\
      						currency_code, currency_rate, url, reference, branding_theme_id, sent_to_contact,\
      						has_attachments, created_at, updated_at)\
      						VALUES ('#{i.invoice_id}', '#{i.invoice_number}',\
      						'#{i.contact_id}', '#{contact_name}', '#{i.sub_total(calculate_line_amount)}', '#{i.total_tax(calculate_line_amount)}',\
      						'#{i.total(calculate_line_amount)}', '#{i.total_discount}', '#{i.amount_due}', '#{i.amount_paid}',\
      						'#{i.amount_credited}', '#{date}', '#{due_date}', '#{fully_paid_on_date}',\
      						'#{expected_payment_date}', '#{updated_date}', '#{i.status}', '#{i.line_amount_types}',\
      						'#{i.type}', '#{i.currency_code}', '#{i.currency_rate}',\
      						'#{url}', '#{reference}', '#{i.branding_theme_id}', '#{sent_to_contact}',\
      						'#{has_attachments}', '#{time}', '#{time}')"

                else

                    sql = "UPDATE xero_invoices SET invoice_number = '#{i.invoice_number}',\
        						xero_contact_id = '#{i.contact_id}', contact_name = '#{contact_name}',\
        						sub_total = '#{i.sub_total(calculate_line_amount)}', total_tax = '#{i.total_tax(calculate_line_amount)}',\
        						total = '#{i.total(calculate_line_amount)}', total_discount = '#{i.total_discount}',\
        						amount_due = '#{i.amount_due}', amount_paid = '#{i.amount_paid}',\
        						amount_credited = '#{i.amount_credited}', date = '#{date}', due_date = '#{due_date}',\
        						fully_paid_on_date = '#{fully_paid_on_date}', expected_payment_date = '#{expected_payment_date}',\
        						updated_date = '#{updated_date}', status = '#{i.status}',\
        						line_amount_types = '#{i.line_amount_types}', invoice_type = '#{i.type}',\
        						currency_code = '#{i.currency_code}', currency_rate = '#{i.currency_rate}',\
        						url = '#{url}', reference = '#{i.reference}', branding_theme_id = '#{i.branding_theme_id}',\
        						sent_to_contact = '#{sent_to_contact}', has_attachments = '#{has_attachments}', updated_at = '#{time}'\
        						WHERE xero_invoice_id = '#{i.invoice_id}'"

               end

               order = Order.where(id: i.invoice_number).first
               next if order.nil?

               order.update(status_id: 10) if i.amount_due == 0 && order.status_id==12

                ActiveRecord::Base.connection.execute(sql)

                XeroInvoiceLineItem.new.download_data_from_api(i.line_items, i.invoice_id, i.invoice_number)
            end

            page_num += 1

            invoices = xero.Invoice.all(page: page_num, modified_since: modified_since_time)

          end
    end

    def valid_invoice(invoice)
        if invoice.type != 'ACCREC'
            false
        else
            true
        end
    end

    def invoice_doesnt_exist(invoice_id)
        if XeroInvoice.where(xero_invoice_id: invoice_id).count == 0
            true
        else
            false
       end
    end

    def self.get_invoice_id_for_valid_invoice(invoice_number)
        invoice = where("invoice_number = '#{invoice_number}' and (status = 'PAID' or status = 'AUTHORISED')")
        if invoice.count == 1
            return invoice.first.xero_invoice_id
        else
            return false
        end
     end

    def self.find_by_order_id(order_id)
        if invoice_id = XeroInvoice.get_invoice_id_for_valid_invoice(order_id.to_s)
            invoice_id
        elsif invoice = XeroInvoice.get_invoice_id_for_valid_invoice('BC' + order_id.to_s)
            invoice
        end
     end

     def self.find_by_order_ids(order_ids)
       where("xero_invoices.invoice_number IN (?)", order_ids)
     end

    def self.filter_by_invoice_number(invoice_number)
        invoice = where(invoice_number: invoice_number.to_s)
        if invoice.empty?
            return nil
        else
            return invoice.first
        end
     end

    def self.is_submitted(order_id)
        where(invoice_number: order_id.to_s, status: 'SUBMITTED').count == 1
     end

    def self.paid(xero_invoice)
        if xero_invoice && xero_invoice.status == 'PAID'
            ['PAID', xero_invoice.amount_due]
        end
     end

    def self.unpaid(xero_invoice)
        if xero_invoice && xero_invoice.status == 'AUTHORISED' && xero_invoice.amount_due > 0 && xero_invoice.amount_paid == 0
            ['UNPAID', xero_invoice.amount_due]
        end
     end

    def self.partially_paid(xero_invoice)
        if xero_invoice && xero_invoice.status == 'AUTHORISED' && xero_invoice.amount_paid > 0\
           && xero_invoice.amount_paid < xero_invoice.amount_due
            ['PARTIALLY-PAID', xero_invoice.amount_due]
        end
     end

     def self.over(xero_invoice)
       if xero_invoice && xero_invoice.status == 'AUTHORISED' && xero_invoice.amount_due > 0
         date_diff = Date.today().mjd - xero_invoice.due_date.to_date.mjd
         return unless date_diff > 0
         if date_diff < 15
           ['Over', xero_invoice.amount_due]
         elsif date_diff < 30
           ['Over-15', xero_invoice.amount_due]
         elsif date_diff < 60
           ['Over-30', xero_invoice.amount_due]
         elsif date_diff
           ['Over-60', xero_invoice.amount_due]
         end
       end
     end

    def self.sum_amount_due
        sum('xero_invoices.amount_due')
      end

    def self.group_by_month
        group(DATE_FORMAT('xero_invoices.date', '%Y-%m-01'))
      end

    def self.filter_by_contact_id(contact_id)
      return where(xero_contact_id: contact_id) unless contact_id.nil? || contact_id.blank?
      all
    end

    def self.group_by_week
        group('WEEK(xero_invoices.date)')
      end

    def self.group_by_contact_id
        group('xero_invoices.contact_id')
      end

    def self.has_amount_due
        where('xero_invoices.amount_due > 0 AND xero_invoices.status LIKE "AUTHORISED"')
      end
    def self.order_by_due_date
      order(:due_date)
    end

    def self.over_due_invoices
      where("due_date < '#{Date.today}'")
    end

    def self.period_select(until_date)
        where("(xero_invoices.date <= '#{until_date}' or xero_invoices.due_date <= '#{until_date}') and xero_invoices.amount_due > 0 ")
      end

    def self.limited_period_select_due_date(select_days)
      sql = "xero_invoices.amount_due > 0 AND ("
      select_days.each do |days|
        start_date, end_date = days.split('|')
        sql += " (xero_invoices.due_date>='#{start_date}' AND xero_invoices.due_date<='#{end_date}')"
        sql += " OR "
      end
      sql = sql[0..-4]
      sql += ")"
      where(sql)
      end

      def self.limited_period_select_date(select_days)
        sql = "xero_invoices.amount_due > 0 AND ("
        select_days.each do |days|
          start_date, end_date = days.split('|')
          sql += " (xero_invoices.date>='#{start_date}' AND xero_invoices.date<='#{end_date}')"
          sql += " OR "
        end
        sql = sql[0..-4]
        sql += ")"
        where(sql)
        end
end
