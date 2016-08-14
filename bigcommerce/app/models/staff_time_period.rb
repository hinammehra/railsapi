require 'csv'

class StaffTimePeriod < ActiveRecord::Base

	belongs_to :staff

	def update_this_month(time_period)
		set_time_zone = 'Melbourne'

		StaffTimePeriod.update(time_period.id, {"start_date" => Date.today.at_beginning_of_month, "end_date" => Date.today})
	end

	def update_last_month(time_period)
		set_time_zone = 'Melbourne'
		StaffTimePeriod.update(time_period.id, start_date: Date.today.at_beginning_of_month.last_month, end_date: Date.today.at_end_of_month.last_month)
	end

	def update_using_default_start_date(time_period)
		set_time_zone = 'Melbourne'
		StaffTimePeriod.update(time_period.id, start_date: Date.today - time_period.start_day, end_date: Date.today - time_period.end_day)

	end

	def update_quarter(time_period)

	end

	def update_this_year(time_period)

	end

	def update_all
		time_periods = StaffTimePeriod.all
		time_periods.each { |t| StaffTimePeriod.new.send(t.update_function, t)}
	end

end
