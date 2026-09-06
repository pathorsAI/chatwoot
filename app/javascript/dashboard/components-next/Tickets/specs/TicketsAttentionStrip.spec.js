import { mount } from '@vue/test-utils';
import TicketsAttentionStrip from '../TicketsAttentionStrip.vue';

const mountStrip = props =>
  mount(TicketsAttentionStrip, {
    props: {
      counts: {
        triage: 5,
        overdue: 2,
        customerReplied: 3,
        mine: 4,
        waitingCustomer: 6,
      },
      ...props,
    },
    global: {
      mocks: { $t: key => key },
      stubs: { Icon: true },
      plugins: [],
    },
  });

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

describe('TicketsAttentionStrip', () => {
  it('shows a chip per attention slice with its count', () => {
    const wrapper = mountStrip();

    expect(
      wrapper.find('[data-test-id="attention-chip-triage"]').text()
    ).toContain('5');
    expect(
      wrapper.find('[data-test-id="attention-chip-overdue"]').text()
    ).toContain('2');
    expect(
      wrapper.find('[data-test-id="attention-chip-waitingCustomer"]').text()
    ).toContain('6');
  });

  it('emits the chip key when a chip is clicked', async () => {
    const wrapper = mountStrip();

    await wrapper
      .find('[data-test-id="attention-chip-triage"]')
      .trigger('click');
    await wrapper
      .find('[data-test-id="attention-chip-customerReplied"]')
      .trigger('click');

    expect(wrapper.emitted('toggle')).toEqual([
      ['triage'],
      ['customerReplied'],
    ]);
  });

  it('marks the chips whose filter is applied', () => {
    const wrapper = mountStrip({ activeKeys: ['overdue'] });

    expect(
      wrapper
        .find('[data-test-id="attention-chip-overdue"]')
        .attributes('aria-pressed')
    ).toBe('true');
    expect(
      wrapper
        .find('[data-test-id="attention-chip-mine"]')
        .attributes('aria-pressed')
    ).toBe('false');
  });

  it('dims a slice that is empty', () => {
    const wrapper = mountStrip({ counts: { triage: 0, overdue: 2 } });

    expect(
      wrapper.find('[data-test-id="attention-chip-triage"]').classes()
    ).toContain('opacity-60');
    expect(
      wrapper.find('[data-test-id="attention-chip-overdue"]').classes()
    ).not.toContain('opacity-60');
  });
});
