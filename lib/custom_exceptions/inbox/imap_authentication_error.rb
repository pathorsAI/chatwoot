# frozen_string_literal: true

# Raised when the IMAP server rejects the channel's credentials during the authentication
# step, so callers can tell a bad login apart from a failing later command or a network error.
class CustomExceptions::Inbox::ImapAuthenticationError < CustomExceptions::Base
  def message
    @data[:message]
  end
end
