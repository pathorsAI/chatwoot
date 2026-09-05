import { mount } from '@vue/test-utils';
import SidebarUnreadBadge from '../SidebarUnreadBadge.vue';

const mountBadge = props => mount(SidebarUnreadBadge, { props });

describe('SidebarUnreadBadge', () => {
  it('renders the neutral pill by default', () => {
    const badge = mountBadge({ count: 3 }).find(
      '[data-test-id="sidebar-unread-badge"]'
    );

    expect(badge.classes()).toContain('bg-n-slate-4');
    expect(badge.attributes('data-tone')).toBe('neutral');
  });

  it('paints work nobody has picked up in the brand colour', () => {
    const badge = mountBadge({ count: 5, tone: 'attention' }).find(
      '[data-test-id="sidebar-unread-badge"]'
    );

    expect(badge.classes()).toContain('bg-n-brand');
    expect(badge.classes()).not.toContain('bg-n-slate-4');
  });

  it('paints late work in the danger colour', () => {
    const badge = mountBadge({ count: 2, tone: 'danger' }).find(
      '[data-test-id="sidebar-unread-badge"]'
    );

    expect(badge.classes()).toContain('bg-n-ruby-9');
  });

  it('leaves informational counts without a fill', () => {
    const badge = mountBadge({ count: 31, tone: 'muted' }).find(
      '[data-test-id="sidebar-unread-badge"]'
    );

    expect(badge.classes()).toContain('text-n-slate-10');
    expect(badge.classes()).not.toContain('bg-n-slate-4');
  });

  it('exposes the tooltip explaining the number', () => {
    const badge = mountBadge({
      count: 5,
      title: '5 conversations waiting for an agent',
    }).find('[data-test-id="sidebar-unread-badge"]');

    expect(badge.attributes('title')).toBe(
      '5 conversations waiting for an agent'
    );
  });
});
