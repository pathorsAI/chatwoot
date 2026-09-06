import axios from 'axios';
import { actions, mutations } from '../../ticketCounts';
import types from '../../../mutation-types';

const commit = vi.fn();
global.axios = axios;
vi.mock('axios');

describe('#actions', () => {
  beforeEach(() => {
    commit.mockClear();
    axios.get.mockReset();
  });

  describe('#fetch', () => {
    it('commits the counts when the API is successful', async () => {
      const data = {
        triage: 5,
        overdue: 2,
        mine: 4,
        customer_replied: 3,
        waiting_customer: 6,
        all: 31,
      };
      axios.get.mockResolvedValue({ data });

      await actions.fetch({ commit });

      expect(axios.get).toHaveBeenCalledWith(
        expect.stringContaining('/tickets/counts')
      );
      expect(commit.mock.calls).toEqual([[types.SET_TICKET_COUNTS, data]]);
    });

    it('does not commit when the API fails', async () => {
      axios.get.mockRejectedValue({ message: 'Incorrect header' });

      await actions.fetch({ commit });

      expect(commit).not.toHaveBeenCalled();
    });
  });

  describe('#refresh', () => {
    beforeEach(() => vi.useFakeTimers());
    afterEach(() => vi.useRealTimers());

    it('collapses a burst of events into a single fetch', () => {
      const dispatch = vi.fn();

      actions.refresh({ dispatch });
      actions.refresh({ dispatch });
      actions.refresh({ dispatch });

      expect(dispatch).not.toHaveBeenCalled();

      vi.advanceTimersByTime(800);

      expect(dispatch.mock.calls).toEqual([['fetch']]);
    });
  });
});

describe('#mutations', () => {
  it('drops counts the API could not produce', () => {
    const state = {};

    mutations[types.SET_TICKET_COUNTS](state, { triage: '5', overdue: null });

    expect(state).toEqual({
      triage: 5,
      overdue: 0,
      mine: 0,
      customerReplied: 0,
      waitingCustomer: 0,
      all: 0,
    });
  });
});
