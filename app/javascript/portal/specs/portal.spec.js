import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { JSDOM } from 'jsdom';
import {
  InitializationHelpers,
  openExternalLinksInNewTab,
} from '../portalHelpers';

describe('InitializationHelpers.initializeLocaleDropdown', () => {
  let dom;
  let document;
  let window;

  const markup = `<!DOCTYPE html><html><body>
      <button id="toggle-locale" aria-expanded="false"></button>
      <div id="locale-dropdown" aria-hidden="true">
        <a href="/hc/test-slug/fr">French</a>
      </div>
    </body></html>`;

  beforeEach(() => {
    dom = new JSDOM(markup, { url: 'http://localhost/' });
    document = dom.window.document;
    window = dom.window;
    global.document = document;
    global.window = window;
  });

  afterEach(() => {
    dom = null;
    document = null;
    window = null;
    delete global.document;
    delete global.window;
  });

  it('does nothing when the portal publishes a single locale and no switcher is rendered', () => {
    document.getElementById('toggle-locale').remove();
    const documentSpy = vi.spyOn(document, 'addEventListener');

    InitializationHelpers.initializeLocaleDropdown();

    expect(documentSpy).not.toHaveBeenCalled();
    documentSpy.mockRestore();
  });

  it('opens on the trigger and reflects it on aria-expanded', () => {
    InitializationHelpers.initializeLocaleDropdown();
    const toggle = document.getElementById('toggle-locale');
    const dropdown = document.getElementById('locale-dropdown');

    toggle.dispatchEvent(new window.MouseEvent('click', { bubbles: true }));

    expect(dropdown.dataset.dropdownOpen).toBe('true');
    expect(dropdown.getAttribute('aria-hidden')).toBe('false');
    expect(toggle.getAttribute('aria-expanded')).toBe('true');
  });

  it('closes on an outside click but stays open while clicking inside', () => {
    InitializationHelpers.initializeLocaleDropdown();
    const toggle = document.getElementById('toggle-locale');
    const dropdown = document.getElementById('locale-dropdown');
    toggle.dispatchEvent(new window.MouseEvent('click', { bubbles: true }));

    dropdown
      .querySelector('a')
      .dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
    expect(dropdown.dataset.dropdownOpen).toBe('true');

    document.body.dispatchEvent(
      new window.MouseEvent('click', { bubbles: true })
    );
    expect(dropdown.dataset.dropdownOpen).toBe('false');
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
  });

  it('closes on Escape', () => {
    InitializationHelpers.initializeLocaleDropdown();
    const toggle = document.getElementById('toggle-locale');
    const dropdown = document.getElementById('locale-dropdown');
    toggle.dispatchEvent(new window.MouseEvent('click', { bubbles: true }));

    document.dispatchEvent(
      new window.KeyboardEvent('keydown', { key: 'Escape', bubbles: true })
    );

    expect(dropdown.dataset.dropdownOpen).toBe('false');
  });
});

describe('openExternalLinksInNewTab', () => {
  let dom;
  let document;
  let window;

  beforeEach(() => {
    dom = new JSDOM(
      `<!DOCTYPE html>
      <html>
        <body>
          <div id="cw-article-content">
            <a href="https://external.com" id="external">External</a>
            <a href="https://app.chatwoot.com/page" id="internal">Internal</a>
            <a href="https://custom.domain.com/page" id="custom">Custom</a>
            <a href="https://example.com" id="nested"><code>Code</code><strong>Bold</strong></a>
            <ul>
              <li>Visit the preferences centre here &gt; <a href="https://external.com" id="list-link"><strong>https://external.com</strong></a></li>
            </ul>
          </div>
        </body>
      </html>`,
      { url: 'https://app.chatwoot.com/hc/article' }
    );

    document = dom.window.document;
    window = dom.window;

    window.portalConfig = {
      customDomain: 'custom.domain.com',
      hostURL: 'app.chatwoot.com',
    };

    global.document = document;
    global.window = window;
  });

  afterEach(() => {
    dom = null;
    document = null;
    window = null;
    delete global.document;
    delete global.window;
  });

  const simulateClick = selector => {
    const element = document.querySelector(selector);
    const event = new window.MouseEvent('click', { bubbles: true });
    element.dispatchEvent(event);
    return element.closest('a') || element;
  };

  it('opens external links in new tab', () => {
    openExternalLinksInNewTab();

    const link = simulateClick('#external');
    expect(link.target).toBe('_blank');
    expect(link.rel).toBe('noopener noreferrer');
  });

  it('preserves internal links', () => {
    openExternalLinksInNewTab();

    const internal = simulateClick('#internal');
    const custom = simulateClick('#custom');

    expect(internal.target).not.toBe('_blank');
    expect(custom.target).not.toBe('_blank');
  });

  it('handles clicks on nested elements', () => {
    openExternalLinksInNewTab();

    simulateClick('#nested code');
    simulateClick('#nested strong');

    const link = document.getElementById('nested');
    expect(link.target).toBe('_blank');
    expect(link.rel).toBe('noopener noreferrer');
  });

  it('handles links inside list items with strong tags', () => {
    openExternalLinksInNewTab();

    // Click on the strong element inside the link in the list
    simulateClick('#list-link strong');

    const link = document.getElementById('list-link');
    expect(link.target).toBe('_blank');
    expect(link.rel).toBe('noopener noreferrer');
  });

  it('opens external links in a new tab even if customDomain is empty', () => {
    window = dom.window;
    window.portalConfig = {
      hostURL: 'app.chatwoot.com',
    };

    global.window = window;

    openExternalLinksInNewTab();

    const link = simulateClick('#external');
    const internal = simulateClick('#internal');
    const custom = simulateClick('#custom');

    expect(link.target).toBe('_blank');
    expect(link.rel).toBe('noopener noreferrer');

    expect(internal.target).not.toBe('_blank');
    // this will be blank since the configs customDomain is empty
    // which is a fair expectation
    expect(custom.target).toBe('_blank');
  });

  it('opens external links in a new tab even if hostURL is empty', () => {
    window = dom.window;
    window.portalConfig = {
      customDomain: 'custom.domain.com',
    };

    global.window = window;

    openExternalLinksInNewTab();

    const link = simulateClick('#external');
    const internal = simulateClick('#internal');
    const custom = simulateClick('#custom');

    expect(link.target).toBe('_blank');
    expect(link.rel).toBe('noopener noreferrer');

    expect(internal.target).not.toBe('_blank');
    expect(custom.target).not.toBe('_blank');
  });
});
