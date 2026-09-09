# Every URL the public help center renders is built here. They are split out of
# PortalHelper because the rules are subtle and shared: the locale has to survive
# each hop, and the plain (iframe) layout has to keep its query string.
module PortalLinksHelper
  def theme_query_string(theme)
    theme.present? && theme != 'system' ? "?theme=#{theme}" : ''
  end

  def portal_query_string(theme, is_plain_layout_enabled)
    query_params = {}
    query_params[:theme] = theme if theme.present? && theme != 'system'
    query_params[:show_plain_layout] = true if is_plain_layout_enabled
    query_params.present? ? "?#{query_params.to_query}" : ''
  end

  def generate_home_link(portal_slug, portal_locale, theme, is_plain_layout_enabled)
    if is_plain_layout_enabled
      "/hc/#{portal_slug}/#{portal_locale}#{portal_query_string(theme, is_plain_layout_enabled)}"
    else
      "/hc/#{portal_slug}/#{portal_locale}"
    end
  end

  # The locale a portal link should be built with. Falls back to the portal
  # default instead of emitting a locale-less URL, which `hc/:slug/:locale`
  # cannot route.
  def portal_link_locale(portal, locale)
    locale.presence || portal.default_locale
  end

  # Ticket routes carry no `:locale` segment on purpose: `hc/:slug/tickets` is
  # declared before `hc/:slug/:locale` (config/routes.rb) so that `tickets` is
  # not swallowed as a locale. The locale therefore has to ride along as a query
  # param, and EVERY ticket link and form action must carry it — miss one and
  # the whole ticket flow silently drops back to the portal default.
  def portal_ticket_link(portal, sub_path = '', locale = nil)
    path = "/hc/#{portal.slug}/tickets#{sub_path}"
    return path if locale.blank? || locale == portal.default_locale

    "#{path}?#{{ locale: locale }.to_query}"
  end

  # Where the language switcher should send you: the page you are on, in another
  # language. Switching used to always jump to the portal home, which threw away a
  # half-filled ticket form. Articles are the exception — they exist per locale, so
  # there is no counterpart to land on and home is the honest destination.
  def portal_locale_switch_link(portal, target_locale)
    ticket_root = "/hc/#{portal.slug}/tickets"
    path = request.path

    return portal_ticket_link(portal, path.delete_prefix(ticket_root), target_locale) if path == ticket_root || path.start_with?("#{ticket_root}/")

    rest = locale_scoped_remainder(portal, path)
    return "/hc/#{portal.slug}/#{target_locale}#{rest}" if rest

    # The switcher is only rendered in layouts that have a header, never the plain
    # (iframe) one, so there is no theme/plain query string to carry here.
    generate_home_link(portal.slug, target_locale, nil, false)
  end

  # `/hc/:slug/:locale/categories/x` => `/categories/x`, and nil when the path
  # carries no locale segment for us to swap (article pages, the bare portal root).
  def locale_scoped_remainder(portal, path)
    prefix = "/hc/#{portal.slug}/"
    return unless path.start_with?(prefix)

    segment, _, rest = path.delete_prefix(prefix).partition('/')
    return unless portal.allowed_locale_codes.include?(segment)

    rest.present? ? "/#{rest}" : ''
  end

  def generate_category_link(params)
    portal_slug = params[:portal_slug]
    category_locale = params[:category_locale]
    category_slug = params[:category_slug]
    theme = params[:theme]
    is_plain_layout_enabled = params[:is_plain_layout_enabled]

    if is_plain_layout_enabled
      "/hc/#{portal_slug}/#{category_locale}/categories/#{category_slug}#{portal_query_string(theme, is_plain_layout_enabled)}"
    else
      "/hc/#{portal_slug}/#{category_locale}/categories/#{category_slug}"
    end
  end

  def generate_article_link(portal_slug, article_slug, theme, is_plain_layout_enabled)
    if is_plain_layout_enabled
      "/hc/#{portal_slug}/articles/#{article_slug}#{portal_query_string(theme, is_plain_layout_enabled)}"
    else
      "/hc/#{portal_slug}/articles/#{article_slug}"
    end
  end
end
