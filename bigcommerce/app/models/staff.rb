require 'csv'

class Staff < ActiveRecord::Base
	has_many :customers
	has_many :orders

	has_many :staff_time_periods
	has_one :default_average_period
	has_one :default_start_date

	# validates :email, unique: true

	has_secure_password

	# Create a new user
	# Staff.create(name: , email: , password: , password_confirmation: )

	def csv_import
		CSV.foreach("db/csv/staff.csv", headers: true) do |row|
			row_hash = row.to_hash
			Staff.create(id: row_hash['id'], firstname: row_hash['FirstName'], lastname: row_hash['LastName'],\
				nickname: row_hash['NickName'], email: row_hash['Email'], logon_details: row_hash['LogonDetails'],\
				contact_number: row_hash['Mobile'], state: row_hash['State'], country: row_hash['Country'],\
				user_type: row_hash['UserType'], display_report: row_hash['DisplayReport'],\
				invoice_rights: row_hash['InvoiceRights'], product_rights: row_hash['ProductRights'],\
				payment_rights: row_hash['PaymentRights'], active: row_hash['Active'])
		end
	end
end
