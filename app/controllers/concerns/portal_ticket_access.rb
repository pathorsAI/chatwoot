# Magic-link identity for the public ticket list. A visitor asks for a link by
# email, and redeeming it swaps the signed token for a short-lived session — the
# portal has no accounts, so this is the whole of "logged in" here.
module PortalTicketAccess
  extend ActiveSupport::Concern

  # A magic link is only good for reaching one portal's ticket list, and only for
  # 15 minutes. Once redeemed the session cookie carries the identity instead.
  ACCESS_TOKEN_VALIDITY = 15.minutes
  SESSION_VALIDITY = 30.minutes

  private

  # The link is followed from a mail client, so the locale cannot be recovered
  # from anywhere else — it has to be baked into the URL or the visitor lands
  # back on the portal default after a round trip through their inbox.
  def deliver_access_link(contact)
    token = contact.signed_id(purpose: token_purpose, expires_in: ACCESS_TOKEN_VALIDITY)
    query = { token: token, locale: (@locale unless @locale == @portal.default_locale) }.compact
    verify_url = "#{request.base_url}/hc/#{@portal.slug}/tickets/verify?#{query.to_query}"

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
    redirect_to helpers.portal_ticket_link(@portal, '/access', @locale)
  end

  def contact_tickets
    ::Ticket.joins(:conversation)
            .where(account_id: @portal.account_id, conversations: { contact_id: @contact.id })
            .includes(:conversation)
  end
end
