require 'rails_helper'

RSpec.describe Portal do
  context 'with validations' do
    it { is_expected.to validate_presence_of(:account_id) }
    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:categories) }
    it { is_expected.to have_many(:folders) }
    it { is_expected.to have_many(:articles) }
    it { is_expected.to have_many(:inboxes) }
  end

  describe 'validations' do
    let!(:account) { create(:account) }
    let!(:portal) { create(:portal, account_id: account.id) }

    context 'when set portal config' do
      it 'Adds default allowed_locales en' do
        expect(portal.config).to be_present
        expect(portal.config['allowed_locales']).to eq(['en'])
        expect(portal.config['default_locale']).to eq('en')
        expect(portal.config['draft_locales']).to eq([])
      end

      it 'Does not allow any other config than allowed_locales' do
        portal.update(config: { 'some_other_key': 'test_value' })
        expect(portal).not_to be_valid
        expect(portal.errors.full_messages[0]).to eq('Config in portal on some_other_key is not supported.')
      end

      it 'falls back to no drafted locales for existing portals' do
        portal.config = { 'allowed_locales' => %w[en es], 'default_locale' => 'en' }

        expect(portal.draft_locale_codes).to eq([])
        expect(portal.public_locale_codes).to eq(%w[en es])
      end

      it 'preserves drafted locales when draft_locales is omitted on update' do
        portal.update!(config: { allowed_locales: %w[en es fr], draft_locales: ['es'], default_locale: 'en' })

        portal.assign_attributes(config: { allowed_locales: %w[en es fr], default_locale: 'en' })
        portal.valid?

        expect(portal.config['draft_locales']).to eq(['es'])
      end

      it 'does not allow drafting the default locale' do
        portal.update(config: { allowed_locales: %w[en es], draft_locales: ['en'], default_locale: 'en' })

        expect(portal).not_to be_valid
        expect(portal.errors.full_messages).to include('Config default locale cannot be drafted.')
      end

      it 'converts empty string to nil' do
        portal.update(custom_domain: '')
        expect(portal.custom_domain).to be_nil
      end

      context 'with locale_translations' do
        it 'allows valid locale translations' do
          portal.update(config: { allowed_locales: %w[en es], default_locale: 'en',
                                  locale_translations: { 'es' => { 'name' => 'Centro', 'page_title' => 'Título', 'header_text' => 'Hola' } } })

          expect(portal).to be_valid
        end

        it 'rejects unknown fields within a locale translation' do
          portal.update(config: { allowed_locales: %w[en es], default_locale: 'en',
                                  locale_translations: { 'es' => { 'tagline' => 'nope' } } })

          expect(portal).not_to be_valid
        end

        it 'retains a locale override after it becomes the default so it can still be edited' do
          portal.update!(config: { allowed_locales: %w[en es], default_locale: 'en',
                                   locale_translations: { 'es' => { 'name' => 'Centro' } } })

          portal.update!(config: { allowed_locales: %w[en es], default_locale: 'es' })

          expect(portal.config['locale_translations']).to eq({ 'es' => { 'name' => 'Centro' } })
        end
      end
    end
  end

  describe '#localized_value' do
    let!(:account) { create(:account) }
    let!(:portal) do
      create(:portal, account_id: account.id, name: 'Help Center', page_title: 'Help Center | Acme',
                      config: { allowed_locales: %w[en es], default_locale: 'en',
                                locale_translations: { 'es' => { 'name' => 'Centro de ayuda' } } })
    end

    it 'returns the override for the requested locale' do
      expect(portal.localized_value('name', 'es')).to eq('Centro de ayuda')
    end

    it 'falls back to the base column when the locale has no override for the field' do
      expect(portal.localized_value('page_title', 'es')).to eq('Help Center | Acme')
    end

    it 'falls back to the base column when the locale has no overrides at all' do
      expect(portal.localized_value('name', 'fr')).to eq('Help Center')
    end

    it 'keeps serving the override for a locale that has become the default' do
      portal.update!(config: { allowed_locales: %w[en es], default_locale: 'es' })

      expect(portal.localized_value('name', 'es')).to eq('Centro de ayuda')
    end

    it "inherits the default locale's override for a locale without its own" do
      portal.update!(config: { allowed_locales: %w[en es fr], default_locale: 'es' })

      expect(portal.localized_value('name', 'fr')).to eq('Centro de ayuda')
    end

    it 'uses the default locale when no locale is given' do
      expect(portal.localized_value('name')).to eq('Help Center')
    end
  end

  describe '#ticket_inbox' do
    let!(:account) { create(:account) }
    let!(:web_widget) { create(:channel_widget, account: account) }
    let!(:portal) { create(:portal, account: account, channel_web_widget: web_widget) }
    let(:email_inbox) { create(:channel_email, account: account).inbox }

    it 'falls back to the live chat widget inbox' do
      expect(portal.ticket_inbox).to eq(web_widget.inbox)
    end

    it 'returns the configured inbox' do
      portal.update!(config: { ticket_inbox_id: email_inbox.id })

      expect(portal.reload.ticket_inbox).to eq(email_inbox)
    end

    it 'stores a numeric string as an integer' do
      portal.update!(config: { ticket_inbox_id: email_inbox.id.to_s })

      expect(portal.config['ticket_inbox_id']).to eq(email_inbox.id)
      expect(portal.ticket_inbox).to eq(email_inbox)
    end

    it 'drops the key when a blank value is sent' do
      portal.update!(config: { ticket_inbox_id: email_inbox.id })

      portal.update!(config: { ticket_inbox_id: '' })

      expect(portal.config).not_to have_key('ticket_inbox_id')
      expect(portal.ticket_inbox).to eq(web_widget.inbox)
    end

    it 'falls back to the widget inbox when the configured inbox is gone' do
      portal.update!(config: { ticket_inbox_id: email_inbox.id })
      email_inbox.destroy!

      expect(portal.reload.ticket_inbox).to eq(web_widget.inbox)
    end

    it 'rejects an inbox belonging to another account' do
      portal.config = { ticket_inbox_id: create(:channel_email, account: create(:account)).inbox.id }

      expect(portal).not_to be_valid
      expect(portal.errors.full_messages).to include('Config ticket inbox must be an email or website inbox of this account')
    end

    it 'rejects an inbox that is neither an email nor a website inbox' do
      portal.config = { ticket_inbox_id: create(:channel_api, account: account).inbox.id }

      expect(portal).not_to be_valid
      expect(portal.errors.full_messages).to include('Config ticket inbox must be an email or website inbox of this account')
    end
  end

  describe '#display_title' do
    let!(:account) { create(:account) }

    it 'prefers the localized page_title' do
      portal = create(:portal, account_id: account.id, name: 'Help Center', page_title: 'Help Center | Acme',
                               config: { allowed_locales: %w[en es], default_locale: 'en',
                                         locale_translations: { 'es' => { 'page_title' => 'Centro | Acme' } } })

      expect(portal.display_title('es')).to eq('Centro | Acme')
    end

    it 'falls back to the localized name when no page_title is set' do
      portal = create(:portal, account_id: account.id, name: 'Help Center',
                               config: { allowed_locales: %w[en es], default_locale: 'en',
                                         locale_translations: { 'es' => { 'name' => 'Centro de ayuda' } } })

      expect(portal.display_title('es')).to eq('Centro de ayuda')
    end

    it 'uses the base values for the default locale' do
      portal = create(:portal, account_id: account.id, name: 'Help Center', page_title: 'Help Center | Acme')

      expect(portal.display_title).to eq('Help Center | Acme')
    end
  end
end
