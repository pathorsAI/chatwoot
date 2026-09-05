require 'rails_helper'

RSpec.describe Email::SenderTriageService do
  let(:account) { create(:account) }
  let(:channel) { instance_double(Channel::Email, newsletter_filter_enabled: true) }
  let(:processed_mail) { instance_double(MailPresenter, bounced?: false, auto_reply?: false, newsletter?: false) }

  def triage(sender_email)
    described_class.new(account: account, channel: channel, processed_mail: processed_mail, sender_email: sender_email).perform
  end

  describe 'notification senders' do
    it 'parks the classic no-reply mailboxes' do
      expect(triage('no-reply@accounts.google.com')).to eq('filtered' => 'notification')
      expect(triage('comments-noreply@example.com')).to eq('filtered' => 'notification')
      expect(triage('donotreply@example.com')).to eq('filtered' => 'notification')
    end

    it 'parks reply-to, notification, alert and mailer mailboxes' do
      expect(triage('b2b_replyto@sinopac.com')).to eq('filtered' => 'notification')
      expect(triage('notifications@github.com')).to eq('filtered' => 'notification')
      expect(triage('notify@stripe.com')).to eq('filtered' => 'notification')
      expect(triage('alerts@grafana.net')).to eq('filtered' => 'notification')
      expect(triage('mailer@example.com')).to eq('filtered' => 'notification')
      expect(triage('automated@example.com')).to eq('filtered' => 'notification')
    end

    it 'leaves people and VERP bounce senders alone' do
      expect(triage('jack@pathors.com')).to eq({})
      expect(triage('service@example.com')).to eq({})
      expect(triage('bounce+token@example.com')).to eq({})
      expect(triage('replytoall@example.com')).to eq({})
    end
  end

  describe 'sender lists' do
    it 'parks blocked domains before any header heuristics' do
      SenderListEntry.create!(account: account, value: 'sinopac.com', list_type: :blocked)
      expect(triage('cardauthservice@sinopac.com')).to eq('sender_list' => 'blocked', 'filtered' => 'blocklist')
    end
  end
end
