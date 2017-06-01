# support activity controller
module ActivityHelper
  def customer_search(params)
    customers = Customer.all
    contacts = Contact.filter_by_customer(params['selected_customers'])

    [customers, contacts]
  end

  # function collection
  def staff_function(staff_id)
    staff = Staff.find(staff_id)
    case staff.user_type
    when 'Sales Executive'
      function = TaskSubject.distinct_function_user('Sales Executive')
    else
      function = TaskSubject.distinct_function
    end
    function
  end

  # default value of function collection
  def default_function_type(user_role)
    role = case user_role
           when 'Accounts'
             'Accounting'
           when 'Sales Executive'
             'Sales'
           else
             'Operations'
           end
    role
  end

  # function collection ; subject collection; methods collection;
  # default function value; promotion rate
  def function_search(params)
    function = staff_function(session[:user_id])
    # Sales/ Operations/ Accounting
    default_function = default_function_type(session[:authority])
    params[:selected_function] = params[:selected_function] || default_function
    promotion = Promotion.all

    subjects = TaskSubject.all
    subjects = subjects.select { |x| x.function == params[:selected_function] }
    methods = TaskMethod.all
    portfolio = Portfolio.all
    [function, subjects, methods, default_function, promotion, portfolio]
  end

  def product_search
    products = Product.stock?
    [products]
  end

  def product_click(products, product_selected)
    return nil if product_selected.nil?
    product = products.select { |x| x.id == product_selected }.first
    return nil if product.nil?
    product
  end

  # ------------------------------------------
  # insert or update for db
  def note_save(note_params, staff_id, parent_task = nil)
    note = Task.new
    note.response_staff = staff_id
    note.last_modified_staff = staff_id
    note.update_attributes(note_params)
    note.is_task = (note.end_date.nil?) ? 0 : 1
    note.end_date = note.date + 1.month if note.end_date.nil?
    note.parent_task = parent_task unless parent_task.nil?
    note.save
    note
  end

  def relation_save(params, task)
    task_id = task.id
    # TODO
    # the format of event
    # task.gcal_status = ('yes' == params['event_column']) ? 'pending' : 'na'
    customers = params.keys.select { |x| x.start_with?('customer ') }.map(&:split).map(&:last)
    staffs = params.keys.select { |x| x.start_with?('staff ') }.map(&:split).map(&:last)
    customers.each do |customer_id|
      tr = TaskRelation.new
      tr.task_id = task_id
      tr.customer_id = customer_id
      tr.staff_id = staffs.delete_at(0)
      tr.save
    end
    staffs.each do |staff_id|
      tr = TaskRelation.new
      tr.staff_id = staff_id
      tr.save
    end
    task.save
  end

  def product_note_save(params, staff_id, task_id)
    product_list = params.keys.select { |x| x.start_with?('note ') }.map(&:split).map(&:last)
    product_list.each do |product_id|
      pn_save(product_id, staff_id, task_id, params['buy_wine'])
    end
  end

  def pn_save(product_id, staff_id, task_id, buy_list)
    pn = ProductNote.new
    pn.task_id = task_id
    pn.created_by = staff_id
    pn.product_id = product_id
    pn.rating = params['rate ' + product_id]
    pn.note = params['note ' + product_id]
    pn.price = params['price ' + product_id]
    pn.product_name = params['product_name ' + product_id]
    pn.price_luc = params['price_luc ' + product_id]
    pn.intention = (buy_list.include? product_id) ? 1 : 0 unless buy_list.nil?
    pn.save
  end

  def task_product_note(params, task, staff_id)
    if params['selected_wine_note'].nil?
      product_note_save(params, staff_id, task.id)
    elsif !params['selected_wine_note'].blank?
      task.pro_note_include = params['selected_wine_note'].join(',')
      task.save
    end
  end

  # -------------------------
  # Task insert
end
