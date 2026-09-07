require 'rails_helper'

RSpec.describe PortalTicketsHelper do
  describe '#portal_tickets_enabled?' do
    let(:account) { create(:account) }
    let(:web_widget) { create(:channel_widget, account: account) }
    let(:portal) { create(:portal, account: account, channel_web_widget: web_widget) }

    before { account.enable_features!('tickets') }

    it 'is enabled when the portal has an inbox and the feature is on' do
      expect(helper.portal_tickets_enabled?(portal)).to be(true)
    end

    it 'is disabled when the feature is off' do
      account.disable_features!('tickets')

      expect(helper.portal_tickets_enabled?(portal)).to be(false)
    end

    it 'is disabled when the portal has no inbox at all' do
      portal.update!(channel_web_widget: nil)

      expect(helper.portal_tickets_enabled?(portal)).to be(false)
    end

    it 'is enabled through a configured email inbox without a widget' do
      email_inbox = create(:channel_email, account: account).inbox
      portal.update!(channel_web_widget: nil, config: { ticket_inbox_id: email_inbox.id })

      expect(helper.portal_tickets_enabled?(portal)).to be(true)
    end
  end
end
