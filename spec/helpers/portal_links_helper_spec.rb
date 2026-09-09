require 'rails_helper'

describe PortalLinksHelper do
  describe '#theme_query_string' do
    context 'when theme is present and not system' do
      it 'returns the correct query string' do
        expect(helper.theme_query_string('dark')).to eq('?theme=dark')
      end
    end

    context 'when theme is not present' do
      it 'returns the correct query string' do
        expect(helper.theme_query_string(nil)).to eq('')
      end
    end

    context 'when theme is system' do
      it 'returns the correct query string' do
        expect(helper.theme_query_string('system')).to eq('')
      end
    end
  end

  describe '#generate_home_link' do
    context 'when theme is not present' do
      it 'returns the correct link' do
        expect(helper.generate_home_link('portal_slug', 'en', nil, true)).to eq(
          '/hc/portal_slug/en?show_plain_layout=true'
        )
      end
    end

    context 'when theme is present and plain layout is enabled' do
      it 'returns the correct link' do
        expect(helper.generate_home_link('portal_slug', 'en', 'dark', true)).to eq(
          '/hc/portal_slug/en?show_plain_layout=true&theme=dark'
        )
      end
    end

    context 'when plain layout is not enabled' do
      it 'returns the correct link' do
        expect(helper.generate_home_link('portal_slug', 'en', 'dark', false)).to eq(
          '/hc/portal_slug/en'
        )
      end
    end
  end

  describe '#portal_ticket_link' do
    # The ticket routes deliberately have no `:locale` segment (config/routes.rb),
    # so the locale can only travel as a query param. Every ticket link has to
    # carry it — the one that does not is where the flow falls back to English.
    let(:portal) { build(:portal, slug: 'test-portal', config: { allowed_locales: %w[en es], default_locale: 'en' }) }

    it 'builds the bare ticket path' do
      expect(helper.portal_ticket_link(portal)).to eq('/hc/test-portal/tickets')
    end

    it 'appends the sub path' do
      expect(helper.portal_ticket_link(portal, '/new')).to eq('/hc/test-portal/tickets/new')
    end

    it 'carries a non-default locale as a query param' do
      expect(helper.portal_ticket_link(portal, '/new', 'es')).to eq('/hc/test-portal/tickets/new?locale=es')
    end

    it 'leaves the default locale out so default URLs stay clean' do
      expect(helper.portal_ticket_link(portal, '/new', 'en')).to eq('/hc/test-portal/tickets/new')
    end

    it 'leaves a blank locale out' do
      expect(helper.portal_ticket_link(portal, '', nil)).to eq('/hc/test-portal/tickets')
      expect(helper.portal_ticket_link(portal, '', '')).to eq('/hc/test-portal/tickets')
    end
  end

  describe '#portal_link_locale' do
    let(:portal) { build(:portal, config: { allowed_locales: %w[en es], default_locale: 'en' }) }

    it 'keeps the locale it is given' do
      expect(helper.portal_link_locale(portal, 'es')).to eq('es')
    end

    it 'falls back to the portal default rather than emitting a locale-less URL' do
      expect(helper.portal_link_locale(portal, nil)).to eq('en')
      expect(helper.portal_link_locale(portal, '')).to eq('en')
    end
  end

  describe '#portal_locale_switch_link' do
    let(:portal) do
      build(:portal, slug: 'test-portal', config: { allowed_locales: %w[en es], default_locale: 'en' })
    end

    def switching_from(path)
      allow(helper.request).to receive(:path).and_return(path)
      helper.portal_locale_switch_link(portal, 'es')
    end

    it 'swaps the locale segment and keeps you on the same page' do
      expect(switching_from('/hc/test-portal/en/categories/billing')).to eq('/hc/test-portal/es/categories/billing')
      expect(switching_from('/hc/test-portal/en')).to eq('/hc/test-portal/es')
    end

    it 'keeps you on the ticket page you are on rather than dropping the form' do
      expect(switching_from('/hc/test-portal/tickets/new')).to eq('/hc/test-portal/tickets/new?locale=es')
      expect(switching_from('/hc/test-portal/tickets')).to eq('/hc/test-portal/tickets?locale=es')
    end

    it 'goes home from an article, which has no counterpart in another locale' do
      expect(switching_from('/hc/test-portal/articles/how-to-refund')).to eq('/hc/test-portal/es')
    end

    it 'does not mistake a path segment that merely looks like a locale' do
      expect(switching_from('/hc/test-portal/enterprise/x')).to eq('/hc/test-portal/es')
    end
  end

  describe '#generate_category_link' do
    context 'when theme is not present' do
      it 'returns the correct link' do
        expect(helper.generate_category_link(
                 portal_slug: 'portal_slug',
                 category_locale: 'en',
                 category_slug: 'category_slug',
                 theme: nil,
                 is_plain_layout_enabled: true
               )).to eq(
                 '/hc/portal_slug/en/categories/category_slug?show_plain_layout=true'
               )
      end
    end

    context 'when theme is present and plain layout is enabled' do
      it 'returns the correct link' do
        expect(helper.generate_category_link(
                 portal_slug: 'portal_slug',
                 category_locale: 'en',
                 category_slug: 'category_slug',
                 theme: 'dark',
                 is_plain_layout_enabled: true
               )).to eq(
                 '/hc/portal_slug/en/categories/category_slug?show_plain_layout=true&theme=dark'
               )
      end
    end

    context 'when plain layout is not enabled' do
      it 'returns the correct link' do
        expect(helper.generate_category_link(
                 portal_slug: 'portal_slug',
                 category_locale: 'en',
                 category_slug: 'category_slug',
                 theme: 'dark',
                 is_plain_layout_enabled: false
               )).to eq(
                 '/hc/portal_slug/en/categories/category_slug'
               )
      end
    end
  end

  describe '#generate_article_link' do
    context 'when theme is not present' do
      it 'returns the correct link' do
        expect(helper.generate_article_link('portal_slug', 'article_slug', nil, true)).to eq(
          '/hc/portal_slug/articles/article_slug?show_plain_layout=true'
        )
      end
    end

    context 'when theme is present and plain layout is enabled' do
      it 'returns the correct link' do
        expect(helper.generate_article_link('portal_slug', 'article_slug', 'dark', true)).to eq(
          '/hc/portal_slug/articles/article_slug?show_plain_layout=true&theme=dark'
        )
      end
    end

    context 'when plain layout is not enabled' do
      it 'returns the correct link' do
        expect(helper.generate_article_link('portal_slug', 'article_slug', 'dark', false)).to eq(
          '/hc/portal_slug/articles/article_slug'
        )
      end
    end
  end
end
