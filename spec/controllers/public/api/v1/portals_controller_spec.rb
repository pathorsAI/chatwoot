require 'rails_helper'

RSpec.describe Public::Api::V1::PortalsController, type: :request do
  let!(:account) { create(:account) }
  let!(:agent) { create(:user, account: account, role: :agent) }
  let!(:portal) { create(:portal, slug: 'test-portal', account_id: account.id, custom_domain: 'www.example.com') }

  before do
    create(:portal, slug: 'test-portal-1', account_id: account.id)
    create(:portal, slug: 'test-portal-2', account_id: account.id)
    create_list(:article, 3, account: account, author: agent, portal: portal, status: :published)
    create_list(:article, 2, account: account, author: agent, portal: portal, status: :draft)
  end

  describe 'GET /public/api/v1/portals/{portal_slug}' do
    it 'redirects to the portal default locale when locale is not present' do
      get "/hc/#{portal.slug}"

      expect(response).to redirect_to("/hc/#{portal.slug}/#{portal.default_locale}")
    end

    it 'Show portal and categories belonging to the portal' do
      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:success)
    end

    it 'Throws unauthorised error for unknown domain' do
      portal.update(custom_domain: 'www.something.com')

      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:unauthorized)
      json_response = response.parsed_body

      expect(json_response['error']).to eql "Domain: www.example.com is not registered with us. \
      Please send us an email at support@chatwoot.com with the custom domain name and account API key"
    end

    context 'when portal has a logo' do
      it 'includes the logo as favicon' do
        # Attach a test image to the portal
        file = Rails.root.join('spec/assets/sample.png').open
        portal.logo.attach(io: file, filename: 'sample.png', content_type: 'image/png')
        file.close

        get "/hc/#{portal.slug}/en"

        expect(response).to have_http_status(:success)
        expect(response.body).to include('<link rel="icon" href=')
      end
    end

    context 'when portal has no logo' do
      it 'does not include a favicon link' do
        # Ensure logo is not attached
        portal.logo.purge if portal.logo.attached?

        get "/hc/#{portal.slug}/en"

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include('<link rel="icon" href=')
      end
    end

    it 'renders no switcher at all when only one locale is published' do
      portal.update!(config: { allowed_locales: %w[en es], draft_locales: ['es'], default_locale: 'en' })

      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('toggle-locale')
      expect(response.body).not_to include("/hc/#{portal.slug}/es")
    end

    it 'allows direct access to drafted locale pages' do
      portal.update!(config: { allowed_locales: %w[en es], draft_locales: ['es'], default_locale: 'en' })

      get "/hc/#{portal.slug}/es"

      expect(response).to have_http_status(:success)
    end

    # A drafted locale is not somewhere a visitor may navigate to, but it is somewhere
    # they can already be. The trigger names where you are; the menu lists where you
    # can go, so the draft shows in the former and not the latter.
    it 'shows the active drafted locale on the trigger but keeps it out of the menu' do
      portal.update!(config: { allowed_locales: %w[en es fr], draft_locales: ['es'], default_locale: 'en' })

      get "/hc/#{portal.slug}/es"

      expect(response).to have_http_status(:success)

      document = Nokogiri::HTML(response.body)
      trigger = document.at_css('#toggle-locale')
      menu = document.at_css('#locale-dropdown')

      expect(trigger).to be_present
      expect(trigger.text).to include('Español')

      hrefs = menu.css('a').map { |link| link['href'] }
      expect(hrefs).to include("/hc/#{portal.slug}/en", "/hc/#{portal.slug}/fr")
      expect(hrefs).not_to include("/hc/#{portal.slug}/es")
    end

    it 'marks the current locale and links every other one to the same page' do
      portal.update!(config: { allowed_locales: %w[en fr], default_locale: 'en' })

      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:success)

      document = Nokogiri::HTML(response.body)
      items = document.css('#locale-dropdown a')

      expect(items.map { |item| item['href'] }).to contain_exactly("/hc/#{portal.slug}/en", "/hc/#{portal.slug}/fr")
      expect(items.select { |item| item['aria-current'] == 'true' }.map(&:text).map(&:strip)).to contain_exactly('English')
    end
  end

  describe 'GET /public/api/v1/portals/{portal_slug}/{locale} layout variants' do
    it 'renders the focused layout when the portal is configured for it' do
      portal.update!(config: { allowed_locales: %w[en], default_locale: 'en', layout: 'focused' })

      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('data-layout="focused"')
      expect(response.body).to include('search-wrap-hero')
    end

    it 'keeps rendering the classic layout when no layout is configured' do
      portal.update!(config: { allowed_locales: %w[en], default_locale: 'en' })

      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('data-layout="focused"')
      expect(response.body).to include('id="portal-bg"')
    end

    # The focused home has three separate ticket entry points (nav, hero action cards,
    # quick links) and each one was added by a different change. Rather than pin each
    # href, assert the invariant: nothing on this page may link into the ticket flow
    # without carrying the locale, or that entry point silently drops the visitor back
    # to the portal default. The action cards shipped doing exactly that.
    context 'when a focused portal is viewed in a non-default locale' do
      let!(:web_widget) { create(:channel_widget, account: account) }

      before do
        account.enable_features!('tickets')
        portal.update!(channel_web_widget: web_widget,
                       config: { allowed_locales: %w[en es], default_locale: 'en', layout: 'focused' })
      end

      it 'carries the locale on every ticket link on the page' do
        get "/hc/#{portal.slug}/es"

        expect(response).to have_http_status(:success)

        ticket_links = Nokogiri::HTML(response.body)
                               .css("a[href*='/hc/#{portal.slug}/tickets']")
                               .map { |link| link['href'] }

        expect(ticket_links).not_to be_empty
        expect(ticket_links).to all(include('locale=es'))
      end

      it 'reaches the action cards, which is where they were being dropped' do
        portal.articles.destroy_all

        get "/hc/#{portal.slug}/es"

        document = Nokogiri::HTML(response.body)

        expect(document.at_css("a[data-testid='focused-action-submit']")['href'])
          .to eq("/hc/#{portal.slug}/tickets/new?locale=es")
        expect(document.at_css("a[data-testid='focused-action-mine']")['href'])
          .to eq("/hc/#{portal.slug}/tickets/access?locale=es")
      end
    end

    context 'when the focused portal has no published articles' do
      let!(:web_widget) { create(:channel_widget, account: account) }

      before do
        account.enable_features!('tickets')
        portal.articles.destroy_all
        portal.update!(channel_web_widget: web_widget,
                       config: { allowed_locales: %w[en], default_locale: 'en', layout: 'focused' })
      end

      it 'renders the ticket entry points instead of the search bar and categories' do
        get "/hc/#{portal.slug}/en"

        expect(response).to have_http_status(:success)
        expect(response.body).to include('data-testid="focused-action-submit"')
        expect(response.body).to include('data-testid="focused-action-mine"')
        expect(response.body).not_to include('search-wrap-hero')
      end
    end
  end

  describe 'GET /public/api/v1/portals/{portal_slug}/{locale} recommended content' do
    let(:category_a) { create(:category, portal: portal, account: account, name: 'Getting Started', locale: 'en') }
    let(:category_b) { create(:category, portal: portal, account: account, name: 'Billing', locale: 'en') }
    let(:alpha) { create(:article, account: account, author: agent, portal: portal, locale: 'en', status: :published, title: 'Alpha Guide') }
    let(:beta) { create(:article, account: account, author: agent, portal: portal, locale: 'en', status: :published, title: 'Beta Guide') }
    let(:gamma) { create(:article, account: account, author: agent, portal: portal, locale: 'en', status: :published, title: 'Gamma Guide') }

    it 'renders recommended articles in the configured order' do
      portal.update!(config: { allowed_locales: %w[en], default_locale: 'en',
                               popular_content: { 'en' => { 'article_ids' => [gamma.id, alpha.id] } } })

      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Recommended articles')
      expect(response.body.index('Gamma Guide')).to be < response.body.index('Alpha Guide')
    end

    it 'drops draft and other-locale ids from the recommended articles' do
      draft = create(:article, account: account, author: agent, portal: portal, locale: 'en', status: :draft, title: 'Draft Secret')
      spanish = create(:article, account: account, author: agent, portal: portal, locale: 'es', status: :published, title: 'Spanish Only')
      portal.update!(config: { allowed_locales: %w[en es], default_locale: 'en',
                               popular_content: { 'en' => { 'article_ids' => [alpha.id, draft.id, spanish.id] } } })

      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Alpha Guide')
      expect(response.body).not_to include('Draft Secret')
      expect(response.body).not_to include('Spanish Only')
    end

    it 'does not leak one locale\'s recommendations into another' do
      portal.update!(config: { allowed_locales: %w[en es], default_locale: 'en',
                               popular_content: { 'es' => { 'article_ids' => [alpha.id] } } })

      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('Recommended articles')
    end

    it 'renders recommended categories as hero pills in the configured order' do
      portal.update!(config: { allowed_locales: %w[en], default_locale: 'en',
                               popular_content: { 'en' => { 'category_ids' => [category_b.id, category_a.id] } } })

      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('recommended-pill')
      expect(response.body).to include('Getting Started', 'Billing')
      expect(response.body.index('Billing')).to be < response.body.index('Getting Started')
    end

    it 'falls back to featured articles when no recommendations are configured' do
      create_list(:article, 6, account: account, author: agent, portal: portal, locale: 'en', status: :published, category: category_a)

      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Featured Articles')
      expect(response.body).not_to include('Recommended articles')
    end

    it 'renders recommended articles in the documentation layout' do
      portal.update!(config: { allowed_locales: %w[en], default_locale: 'en', layout: 'documentation',
                               popular_content: { 'en' => { 'article_ids' => [alpha.id, beta.id] } } })

      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Recommended articles')
      expect(response.body).to include('Alpha Guide', 'Beta Guide')
    end
  end

  describe 'GET /public/api/v1/portals/{portal_slug}/sitemap' do
    context 'when custom_domain is present' do
      it 'returns a valid urlset sitemap with the correct namespace' do
        get "/hc/#{portal.slug}/sitemap.xml"

        expect(response).to have_http_status(:success)

        doc = Nokogiri::XML(response.body)
        expect(doc.errors).to be_empty

        expect(doc.root.name).to eq('urlset')
        expect(doc.root.namespace&.href).to eq('http://www.sitemaps.org/schemas/sitemap/0.9')
      end

      it 'contains valid article URLs for the portal' do
        get "/hc/#{portal.slug}/sitemap.xml"

        expect(response).to have_http_status(:success)

        doc = Nokogiri::XML(response.body)
        doc.remove_namespaces!

        # ensure we are NOT returning a sitemapindex
        expect(doc.xpath('//sitemapindex')).to be_empty

        links = doc.xpath('//url/loc').map(&:text)
        expect(links.length).to eq(3)

        expect(links).to all(
          match(%r{\Ahttps://www\.example\.com/hc/#{Regexp.escape(portal.slug)}/articles/\d+})
        )
      end
    end
  end
end
