require 'rails_helper'

describe Integrations::Github::ProcessorService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Ada Lovelace', email: 'ada@example.com') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }
  let(:hook) { create(:integrations_hook, :github, account: account) }
  let(:ticket) { create(:ticket, conversation: conversation, subject: 'Refund never arrived', ticket_type: 'issue') }
  let(:issues_url) { 'https://api.github.com/repos/pathorsAI/chatwoot/issues' }
  let(:issue_response) do
    { 'html_url' => 'https://github.com/pathorsAI/chatwoot/issues/42', 'number' => 42 }
  end

  describe '#perform' do
    context 'when a ticket is created' do
      before do
        create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming,
                         content: 'I paid last week and the refund never showed up.')
      end

      it 'opens a github issue with the ticket context' do
        stub_request(:post, issues_url).to_return(status: 201, body: issue_response.to_json,
                                                  headers: { 'Content-Type' => 'application/json' })

        described_class.new(hook: hook, event_name: 'ticket.created', event_data: { ticket: ticket }).perform

        expect(WebMock).to have_requested(:post, issues_url)
          .with(headers: { 'Authorization' => 'Bearer github_pat_token', 'X-GitHub-Api-Version' => '2022-11-28' }) { |request|
            body = JSON.parse(request.body)
            expect(body['title']).to eq('Refund never arrived')
            expect(body['body']).to include('Ada Lovelace <ada@example.com>')
            expect(body['body']).to include('issue')
            expect(body['body']).to include("/app/accounts/#{account.id}/conversations/#{conversation.display_id}")
            expect(body['body']).to include('I paid last week and the refund never showed up.')
            expect(body).not_to have_key('labels')
            true
          }
      end

      it 'stores the issue on the conversation and posts a private note' do
        stub_request(:post, issues_url).to_return(status: 201, body: issue_response.to_json,
                                                  headers: { 'Content-Type' => 'application/json' })

        described_class.new(hook: hook, event_name: 'ticket.created', event_data: { ticket: ticket }).perform

        expect(conversation.reload.additional_attributes['github_issue']).to eq(
          'url' => 'https://github.com/pathorsAI/chatwoot/issues/42',
          'number' => 42,
          'repository' => 'pathorsAI/chatwoot'
        )
        note = conversation.messages.where(private: true).last
        expect(note.content).to include('https://github.com/pathorsAI/chatwoot/issues/42')
      end

      it 'applies the configured label' do
        hook.update!(settings: hook.settings.merge('label' => 'support'))
        stub_request(:post, issues_url).to_return(status: 201, body: issue_response.to_json,
                                                  headers: { 'Content-Type' => 'application/json' })

        described_class.new(hook: hook, event_name: 'ticket.created', event_data: { ticket: ticket }).perform

        expect(WebMock).to(have_requested(:post, issues_url)
          .with { |request| JSON.parse(request.body)['labels'] == ['support'] })
      end
    end

    context 'when the conversation already has an issue' do
      it 'does not call the github api' do
        conversation.update!(additional_attributes: { 'github_issue' => { 'number' => 7 } })

        described_class.new(hook: hook, event_name: 'ticket.created', event_data: { ticket: ticket }).perform

        expect(WebMock).not_to have_requested(:post, issues_url)
      end
    end

    context 'when the event is not a ticket creation' do
      it 'does not call the github api' do
        described_class.new(hook: hook, event_name: 'ticket.updated', event_data: { ticket: ticket }).perform

        expect(WebMock).not_to have_requested(:post, issues_url)
      end
    end

    context 'when github rejects the request' do
      it 'logs the failure without raising or recording an issue' do
        stub_request(:post, issues_url).to_return(status: 404, body: { message: 'Not Found' }.to_json,
                                                  headers: { 'Content-Type' => 'application/json' })
        allow(Rails.logger).to receive(:error)

        expect do
          described_class.new(hook: hook, event_name: 'ticket.created', event_data: { ticket: ticket }).perform
        end.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(/404.*Not Found/)
        expect(conversation.reload.additional_attributes['github_issue']).to be_nil
      end
    end
  end
end
