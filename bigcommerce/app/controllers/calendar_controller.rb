require 'calendar_helper.rb'
require 'models_filter.rb'
require 'fuzzystringmatch'
require 'application_helper.rb'

class CalendarController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :confirm_logged_in

  autocomplete :customer_tag, :name, extra_data: [:customer_id, :role, :staff_nickname, :state, :address, :name], full: true, scopes: :no_contacts, display_value: :details

  include CalendarHelper
  include ModelsFilter
  include ApplicationHelper

  def redirect
    uri = Rails.env.development? ? 'http://localhost:3000/callback' : 'http://cms.untappedwines.com.au/callback'
    client = Signet::OAuth2::Client.new(
      client_id: Rails.application.secrets.google_client_id,
      client_secret: Rails.application.secrets.google_client_secret,
      authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
      scope: Google::Apis::CalendarV3::AUTH_CALENDAR,
      additional_parameters: {
        access_type: 'offline', # offline access
        include_granted_scopes: true # incremental auth
      },
      redirect_uri: uri
    )
    redirect_to client.authorization_uri.to_s, event: params[:event]
  end

  def callback
    uri = Rails.env.development? ? 'http://localhost:3000/callback' : 'http://cms.untappedwines.com.au/callback'

    client = Signet::OAuth2::Client.new(
      client_id: Rails.application.secrets.google_client_id,
      client_secret: Rails.application.secrets.google_client_secret,
      token_credential_uri: 'https://accounts.google.com/o/oauth2/token',
      redirect_uri: uri,
      code: params[:code]
    )
    response = client.fetch_access_token!

    session[:authorization] = staff_access_token_update(session[:user_id], response)
    if params[:event]
      redirect_to controller: 'task', action: 'add_task'
    else
      redirect_to action: 'event_censor'
    end
  end

  def local_calendar
    # tempary use, it should be assigned based on the current users' right
    if session[:user_id] == 36
      @staffs = Staff.calendar_list(session[:user_id]).order_by_order
    elsif user_full_right(session[:authority])
      @staffs = Staff.calendar_list.order_by_order
    else
      @staffs = Staff.where(id: session[:user_id])
    end

    _, @order_colour_selected, @colour_guide, @max_date =
      colour_selected(params)

    @selected_staff = params[:calendar_staff_selected]
    params[:start_date] = params[:start_date] || Date.current.to_s
    @start_date = Date.parse params[:start_date]
  end

  def fetch_calendar
    @calendar_staff = params[:calendar_staff_selected]
    @start_date = params[:start_date] || Date.today.to_s
    respond_to do |format|
      format.js
    end
  end

  def fetch_calendar_date
    @calendar_date  = params[:calendar_date_selected] || Date.today.to_s
    @calendar_staff = params[:calendar_staff_selected]
    respond_to do |format|
      format.js
    end
  end

  # online version
  # event sync
  def event_censor
    client = Signet::OAuth2::Client.new(client_id: Rails.application.secrets.google_client_id,
                                        client_secret: Rails.application.secrets.google_client_secret,
                                        additional_parameters: {
                                          'access_type' => 'offline',         # offline access
                                          'include_granted_scopes' => 'true'  # incremental auth
                                        },
                                        token_credential_uri: 'https://accounts.google.com/o/oauth2/token')
    client.update!(session[:authorization])

    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = client

    begin
      # function in calendar_helper
      push_pending_events_to_google
      scrap_from_calendars(service)
      redirect_to action: 'event_check_offline'
      return
    rescue Google::Apis::AuthorizationError
      begin
        response = client.refresh!
      rescue
        redirect_to action: redirect && return
      end
      session[:authorization] = session[:authorization].merge(response)
      retry
    end
    redirect_to action: 'event_check_offline'
  end

  def event_check_offline
    @per_page = params[:per_page] || 5
    @jarow = FuzzyStringMatch::JaroWinkler.create(:native)

    @methods = TaskMethod.all
    @subjects = TaskSubject.sales_subjects

    if !params[:selected_staff].nil?
      @events = Task.filter_by_response(params[:selected_staff]).unconfirmed_event.order_by_staff('ASC').paginate(per_page: @per_page, page: params[:page])
    elsif user_full_right(session[:authority])
      @events = Task.unconfirmed_event.order_by_staff('ASC').paginate(per_page: @per_page, page: params[:page])
    else
      @events = Task.unconfirmed_event.filter_by_staff(session[:user_id]).order_by_staff('ASC').paginate(per_page: @per_page, page: params[:page])
    end

    @staffs = Staff.filter_by_ids(Task.unconfirmed_event.map(&:response_staff).uniq)
  end

  # handle the requests for updating events
  def translate_events
    if params['submit'] == 'reject'
      tasks = Task.filter_by_google_event_id(params['event_id'])
      task = tasks.first
      task.gcal_status = :rejected
      task.save
      redirect_to action: 'event_check_offline'
      return
    end

    if collection_valid_check(params)
      if Task.new.update_event(params['event_id'], params['method'], params['subject'], params['customer'])
        flash[:success] = 'Done'
      else
        flash[:error] = 'Something went wrong'
      end
    else
      flash[:error] = 'Select Right Customer/Method/Subject.'
    end
    redirect_to :back
  end

  def map
    @colour_selected, @order_colour_selected, @colour_guide, @max_date =
      colour_selected(params)

    @customer_type = CustStyle.all
    @customer_style_selected =
      customer_style_filter(params[:selected_cust_style])

    @staff, @staff_selected =
      staff_filter(session, params[:selected_staff])

    @colour_range_sales = { 'lightgreen' => [5000, 100_000],
                            'green' => [3000, 5000],
                            'gold' => [1500, 3000],
                            'coral' => [500, 1500],
                            'red' => [0, 500],
                            'maroon' => [0, 0] }

    case sales_last_order(params)
    when 'Sales'
      # in Helper
      # filter customers with attributes
      @active_sales = true
      @customer_map, @start_date, @end_date = customer_filter_map(params, @colour_selected, @colour_range_sales, @customer_style_selected, @staff)
    when 'Last_Order'
      @active_sales = false
      @customer_map, @start_date, @end_date = customer_last_order_filter(params, @order_colour_selected, @customer_style_selected, @staff)
    end

    # customer table
    order_function, direction = sort_order(params, 'order_by_name', 'ASC')
    @per_page = params[:per_page] || Customer.per_page
    @customers = Customer.filter_by_ids(@customer_map.keys).include_all.send(order_function, direction).paginate(per_page: @per_page, page: params[:page])
  end

end
