import { debounce } from '@chatwoot/utils';
import TicketsAPI from '../../api/tickets';
import types from '../mutation-types';

export const state = {
  triage: 0,
  overdue: 0,
  mine: 0,
  customerReplied: 0,
  waitingCustomer: 0,
  all: 0,
};

export const getters = {
  getCounts: $state => $state,
};

const normalizeCount = count => {
  const parsedCount = Number(count);
  return Number.isFinite(parsedCount) && parsedCount > 0 ? parsedCount : 0;
};

// Realtime events arrive in bursts — a bulk assign or a status sweep can fire
// dozens in a second — and every count is a fresh round trip.
const debouncedFetch = debounce(dispatch => dispatch('fetch'), 800, false);

export const actions = {
  fetch: async ({ commit }) => {
    try {
      const { data } = await TicketsAPI.counts();
      commit(types.SET_TICKET_COUNTS, data);
    } catch (error) {
      // Ignore so the sidebar keeps rendering without badges.
    }
  },
  refresh: ({ dispatch }) => {
    debouncedFetch(dispatch);
  },
};

export const mutations = {
  [types.SET_TICKET_COUNTS]($state, payload = {}) {
    $state.triage = normalizeCount(payload.triage);
    $state.overdue = normalizeCount(payload.overdue);
    $state.mine = normalizeCount(payload.mine);
    $state.customerReplied = normalizeCount(payload.customer_replied);
    $state.waitingCustomer = normalizeCount(payload.waiting_customer);
    $state.all = normalizeCount(payload.all);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
