module PortalFocusedHelper
  # The focused layout doubles as a ticket-only support center: a portal with no
  # published article hides the search bar, the article nav entry and the category grid.
  def portal_has_articles?(portal)
    portal.articles.published.exists?
  end
end
