class Public::Api::V1::Portals::TicketsController < Public::Api::V1::Portals::BaseController
  # A magic link is only good for reaching one portal's ticket list, and only for
  # 15 minutes. Once redeemed the session cookie carries the identity instead.
  ACCESS_TOKEN_VALIDITY = 15.minutes
  SESSION_VALIDITY = 30.minutes

  before_action :ensure_custom_domain_request
  before_action :portal
  before_action :set_portal_locale
  before_action :set_portal_layout
  before_action :set_view_variant
  before_action :ensure_portal_feature_enabled
  before_action :ensure_tickets_enabled
  before_action :set_authenticated_contact, only: [:index, :show]
  before_action :ensure_authenticated_contact, only: [:index, :show]
  layout 'portal'

  def index
    @tickets = contact_tickets.order(updated_at: :desc)
  end

  def show
    @ticket = contact_tickets.find_by(id: params[:id])
    return render_404 if @ticket.blank?

    @messages = @ticket.conversation.messages.chat.includes(:sender, attachments: { file_attachment: :blob }).order(created_at: :asc)
  end

  def new
    @ticket_types = Ticket::TYPES
    @submission = { name: '', email: '', subject: '', ticket_type: nil, description: '' }
    # Set by #create through the redirect, so a refresh cannot resubmit the form.
    @created_display_id = flash[:portal_ticket_created]
    @created_email = flash[:portal_ticket_email]
  end

  def create
    @ticket_types = Ticket::TYPES
    @submission = submission_params
    @errors = submission_errors
    return render :new, status: :unprocessable_entity if @errors.any?

    ticket = build_ticket
    flash[:portal_ticket_created] = ticket.conversation.display_id
    flash[:portal_ticket_email] = @submission[:email]
    redirect_to helpers.portal_ticket_link(@portal, '/new', @locale)
  end

  def access; end

  # Turbo drives the portal forms, and it refuses to render a 200 HTML body in
  # response to a form submission ("Form responses must redirect to another
  # location"). Redirect to a GET page instead so the confirmation shows up.
  def send_access_link
    contact = @portal.account.contacts.from_email(submission_params[:email])
    deliver_access_link(contact) if contact.present?

    redirect_to helpers.portal_ticket_link(@portal, '/access/sent', @locale), status: :see_other
  end

  def access_sent; end

  def verify
    contact = contact_from_token
    if contact.blank?
      @error = I18n.t('public_portal.tickets.access.invalid_token')
      return render :access, status: :unauthorized
    end

    session[:portal_ticket_access] = {
      'portal_id' => @portal.id,
      'contact_id' => contact.id,
      'expires_at' => SESSION_VALIDITY.from_now.to_i
    }
    redirect_to helpers.portal_ticket_link(@portal, '', @locale)
  end

  private

  # `set_locale` (around_action, BaseController) already puts `params[:locale]`
  # into @locale when one was supplied. This used to overwrite it unconditionally,
  # which pinned every ticket page to the portal default however the visitor got
  # here — the strings translated (I18n.locale still followed the param) but every
  # link on the page pointed back at the default locale, so picking a language
  # appeared to bounce straight back.
  def set_portal_locale
    @locale = @portal.default_locale unless requested_public_locale?
  end

  # Only a locale the portal actually publishes may stand: an arbitrary
  # `?locale=` would otherwise reach the content queries.
  def requested_public_locale?
    params[:locale].present? && @portal.public_locale_codes.include?(params[:locale])
  end

  def ensure_tickets_enabled
    render_404 unless helpers.portal_tickets_enabled?(@portal)
  end

  def ticket_inbox
    @ticket_inbox ||= @portal.ticket_inbox
  end

  # ----------------------------------------------------------------------
  # Ticket submission

  def build_ticket
    # An email inbox keys its contact inboxes by address (see ContactInboxBuilder), so reusing
    # the address here lands a reply fetched over IMAP on this same contact inbox.
    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: ticket_inbox.email? ? @submission[:email] : SecureRandom.uuid,
      inbox: ticket_inbox,
      contact_attributes: { name: @submission[:name].presence, email: @submission[:email] }
    ).perform

    conversation = create_conversation(contact_inbox)
    create_description_message(conversation, contact_inbox.contact)

    conversation.create_ticket!(account_id: @portal.account_id, subject: @submission[:subject], ticket_type: @submission[:ticket_type])
  end

  # ConversationBuilder is bypassed on purpose: on a `lock_to_single_conversation` inbox it
  # hands back the contact's existing conversation, and since the email path reuses the
  # contact inbox keyed by address, a second ticket would be appended to the first one's
  # thread and then fail the unique index on tickets.conversation_id. Every ticket is its
  # own conversation. `mail_subject` is what ConversationReplyMailer sends as the outbound
  # subject, which keeps the customer's mail client threading replies onto this conversation.
  def create_conversation(contact_inbox)
    ::Conversation.create!(account_id: contact_inbox.inbox.account_id, inbox_id: contact_inbox.inbox_id,
                           contact_id: contact_inbox.contact_id, contact_inbox_id: contact_inbox.id,
                           additional_attributes: ticket_inbox.email? ? { 'mail_subject' => @submission[:subject] } : {})
  end

  def create_description_message(conversation, contact)
    message = conversation.messages.new(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      sender: contact,
      content: description_content,
      content_attributes: description_content_attributes,
      message_type: :incoming
    )
    uploaded_attachments.each do |uploaded_attachment|
      message.attachments.new(
        account_id: conversation.account_id,
        file_type: helpers.file_type(uploaded_attachment.content_type),
        file: uploaded_attachment
      )
    end
    message.save!
  end

  # On an email inbox the dashboard renders the subject from the email meta header, so
  # it is only folded into the body on the widget fallback where nothing else shows it.
  def description_content
    return @submission[:description] if ticket_inbox.email?

    "**#{@submission[:subject]}**\n\n#{@submission[:description]}"
  end

  def description_content_attributes
    return {} unless ticket_inbox.email?

    { email: { subject: @submission[:subject] } }
  end

  # Files ride along as a plain multipart array, so they never go through strong
  # params: they are read here and handed straight to ActiveStorage.
  def uploaded_attachments
    @uploaded_attachments ||= Array(params[:attachments]).reject(&:blank?)
  end

  def submission_errors
    errors = {}
    errors[:email] = I18n.t('public_portal.tickets.errors.email') unless @submission[:email].match?(Devise.email_regexp)
    errors[:subject] = I18n.t('public_portal.tickets.errors.subject') if @submission[:subject].blank?
    errors[:ticket_type] = I18n.t('public_portal.tickets.errors.ticket_type') if @submission[:ticket_type].blank?
    errors[:description] = I18n.t('public_portal.tickets.errors.description') if @submission[:description].blank?
    errors[:attachments] = attachment_error if attachment_error.present?
    errors
  end

  # The browser blocks these too, but the endpoint is unauthenticated and takes
  # uploads, so the same rules are enforced here before anything is written.
  def attachment_error
    return @attachment_error if defined?(@attachment_error)

    @attachment_error = build_attachment_error
  end

  def build_attachment_error
    return if uploaded_attachments.empty?

    if uploaded_attachments.size > PortalTicketsHelper::MAX_ATTACHMENTS
      return I18n.t('public_portal.tickets.errors.attachments_count', count: PortalTicketsHelper::MAX_ATTACHMENTS)
    end

    oversized = uploaded_attachments.find { |file| file.size > PortalTicketsHelper::MAX_ATTACHMENT_SIZE }
    return I18n.t('public_portal.tickets.errors.attachment_size', filename: oversized.original_filename, size: attachment_size_limit) if oversized

    unsupported = uploaded_attachments.find { |file| !helpers.acceptable_ticket_attachment?(file.content_type) }
    I18n.t('public_portal.tickets.errors.attachment_type', filename: unsupported.original_filename) if unsupported
  end

  def attachment_size_limit
    helpers.number_to_human_size(PortalTicketsHelper::MAX_ATTACHMENT_SIZE)
  end

  def submission_params
    permitted = params.permit(:name, :email, :subject, :ticket_type, :description)
    {
      name: permitted[:name].to_s.strip,
      email: permitted[:email].to_s.strip.downcase,
      # The subject goes out as an SMTP `Subject:` header, so line breaks are collapsed here.
      subject: permitted[:subject].to_s.gsub(/[\r\n]+/, ' ').strip,
      ticket_type: Ticket::TYPES.include?(permitted[:ticket_type]) ? permitted[:ticket_type] : nil,
      description: permitted[:description].to_s.strip
    }
  end

  # ----------------------------------------------------------------------
  # Magic link access

  def deliver_access_link(contact)
    token = contact.signed_id(purpose: token_purpose, expires_in: ACCESS_TOKEN_VALIDITY)
    verify_url = "#{request.base_url}/hc/#{@portal.slug}/tickets/verify?token=#{CGI.escape(token)}"

    PortalTicketAccessMailer.access_link(portal: @portal, contact: contact, verify_url: verify_url).deliver_later
  end

  def contact_from_token
    contact = ::Contact.find_signed(params[:token].to_s, purpose: token_purpose)
    contact if contact&.account_id == @portal.account_id
  end

  def token_purpose
    "portal_ticket_access_#{@portal.id}"
  end

  def set_authenticated_contact
    access = session[:portal_ticket_access]
    return if access.blank?
    return if access['portal_id'] != @portal.id || access['expires_at'].to_i < Time.current.to_i

    @contact = @portal.account.contacts.find_by(id: access['contact_id'])
  end

  def ensure_authenticated_contact
    return if @contact.present?

    session.delete(:portal_ticket_access)
    redirect_to "/hc/#{@portal.slug}/tickets/access"
  end

  def contact_tickets
    ::Ticket.joins(:conversation)
            .where(account_id: @portal.account_id, conversations: { contact_id: @contact.id })
            .includes(:conversation)
  end
end
