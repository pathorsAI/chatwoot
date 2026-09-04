module PortalTicketsHelper
  STATUS_CATEGORY_CLASSES = {
    'triage' => 'bg-amber-100 text-amber-800 dark:bg-amber-500/20 dark:text-amber-200',
    'in_progress' => 'bg-blue-50 text-sky-700 dark:bg-sky-950 dark:text-sky-200',
    'waiting' => 'bg-zinc-100 text-zinc-600 dark:bg-zinc-800 dark:text-zinc-300',
    'done' => 'bg-green-100 text-green-700 dark:bg-green-500/20 dark:text-green-200',
    'closed' => 'bg-zinc-100 text-zinc-500 dark:bg-zinc-800 dark:text-zinc-400'
  }.freeze

  SUBJECT_MAX_LENGTH = 120
  DESCRIPTION_MAX_LENGTH = 5000

  # Attachment rules for the public ticket form. Every entry is also part of
  # Attachment::ACCEPTABLE_FILE_TYPES, so a file that passes here also passes the
  # model validation the widget inbox applies. Images are matched by prefix.
  MAX_ATTACHMENTS = 10
  MAX_ATTACHMENT_SIZE = 10.megabytes
  ATTACHMENT_CONTENT_TYPES = %w[
    application/pdf
    text/plain text/csv application/json
    application/zip application/x-7z-compressed
    application/msword application/vnd.ms-excel application/vnd.ms-powerpoint
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/vnd.openxmlformats-officedocument.presentationml.presentation
  ].freeze

  # The customer facing ticket entry needs a widget inbox to land submissions in,
  # so a portal without one hides the entry altogether.
  def portal_tickets_enabled?(portal)
    portal.channel_web_widget&.inbox.present? && portal.account.feature_enabled?('tickets')
  end

  def ticket_status_category_classes(status_category)
    STATUS_CATEGORY_CLASSES.fetch(status_category)
  end

  # `waiting` splits in two for the customer: waiting on us reads as a neutral
  # state, waiting on them is a call to action.
  def ticket_status_category_label(ticket)
    return I18n.t('public_portal.tickets.status_categories.waiting_customer') if ticket.status_category == 'waiting' && ticket.waiting_customer?

    I18n.t("public_portal.tickets.status_categories.#{ticket.status_category}")
  end

  def ticket_attachment_accept
    (['image/*'] + ATTACHMENT_CONTENT_TYPES).join(',')
  end

  def acceptable_ticket_attachment?(content_type)
    content_type.to_s.start_with?('image/') || ATTACHMENT_CONTENT_TYPES.include?(content_type)
  end
end
