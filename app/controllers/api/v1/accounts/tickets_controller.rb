class Api::V1::Accounts::TicketsController < Api::V1::Accounts::BaseController
  RESULTS_PER_PAGE = 25

  # Params that map straight onto a column of the ticket or of its conversation.
  TICKET_FILTERS = %i[waiting_on ticket_type].freeze
  CONVERSATION_FILTERS = %i[assignee_id team_id contact_id].freeze

  def index
    @tickets = filtered_tickets.order(created_at: :desc).page(params[:page]).per(RESULTS_PER_PAGE)
  end

  # The numbers behind the sidebar badges and the attention strip: everything
  # still on the team's plate, sliced by what makes a case need a human next.
  def counts
    render json: {
      triage: account_tickets.merge(Ticket.with_status_category('triage')).count,
      overdue: unsettled_tickets.where('tickets.due_at < ?', Time.current).count,
      mine: unsettled_tickets.where(conversations: { assignee_id: Current.user.id }).count,
      customer_replied: unsettled_tickets.merge(Ticket.customer_replied).count,
      waiting_customer: unsettled_tickets.where(waiting_on: :customer).count,
      all: unsettled_tickets.count
    }
  end

  private

  def account_tickets
    Ticket.where(account_id: Current.account.id).joins(:conversation)
  end

  def unsettled_tickets
    account_tickets.merge(Ticket.unsettled)
  end

  def filtered_tickets
    scope = account_tickets.preload(:ticket_tasks, conversation: [:assignee, :team])
    scope = apply_status_category(scope)
    scope = apply_settled(scope)
    scope = apply_attribute_filters(scope)
    scope = apply_customer_replied(scope)
    apply_overdue(scope)
  end

  def apply_status_category(scope)
    return scope if params[:status_category].blank?

    scope.merge(Ticket.with_status_category(params[:status_category]))
  end

  # `settled=false` is how a caller asks for everything still on the team's
  # plate without naming one status category at a time.
  def apply_settled(scope)
    return scope unless params[:settled] == 'false'

    scope.merge(Ticket.unsettled)
  end

  def apply_attribute_filters(scope)
    TICKET_FILTERS.each do |key|
      scope = scope.where(key => params[key]) if params[key].present?
    end
    CONVERSATION_FILTERS.each do |key|
      scope = scope.where(conversations: { key => params[key] }) if params[key].present?
    end
    scope
  end

  def apply_customer_replied(scope)
    return scope unless ActiveModel::Type::Boolean.new.cast(params[:customer_replied])

    scope.merge(Ticket.customer_replied).merge(Ticket.unsettled)
  end

  def apply_overdue(scope)
    return scope unless ActiveModel::Type::Boolean.new.cast(params[:overdue])

    scope.where('tickets.due_at < ?', Time.current).merge(Ticket.unsettled)
  end
end
