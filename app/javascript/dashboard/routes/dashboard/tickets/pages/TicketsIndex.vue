<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { useStore } from 'vuex';
import { useTicketsStore } from 'dashboard/stores/tickets';

import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import TicketsAttentionStrip from 'dashboard/components-next/Tickets/TicketsAttentionStrip.vue';
import TicketsFilterBar from 'dashboard/components-next/Tickets/TicketsFilterBar.vue';
import TicketsTable from 'dashboard/components-next/Tickets/TicketsTable.vue';
import {
  TICKETS_PER_PAGE,
  TICKET_STATUS_CATEGORIES,
  TICKET_TYPES,
  TICKET_WAITING_ON_OPTIONS,
} from 'dashboard/components-next/Tickets/constants';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const ticketsStore = useTicketsStore();

const accountId = useMapGetter('getCurrentAccountId');
const currentUserId = useMapGetter('getCurrentUserID');
const ticketCounts = useMapGetter('ticketCounts/getCounts');

const tickets = computed(() => ticketsStore.records);
const meta = computed(() => ticketsStore.meta);
const isFetching = computed(() => ticketsStore.uiFlags.isFetching);

// Filters are seeded from the URL so a shared link restores the same view.
const statusCategory = ref(
  TICKET_STATUS_CATEGORIES.includes(route.query.status_category)
    ? route.query.status_category
    : null
);
const ticketType = ref(
  TICKET_TYPES.includes(route.query.ticket_type)
    ? route.query.ticket_type
    : null
);
const overdue = ref(route.query.overdue === 'true');
// `mine` travels as a flag rather than an agent id so a shared link means
// "assigned to whoever opens it", which is what the sidebar view promises.
const mine = ref(route.query.mine === 'true');
// Cases the customer has answered and cases still parked with them: the two
// halves of "waiting" that the status category alone cannot tell apart.
const customerReplied = ref(route.query.customer_replied === 'true');
const waitingOn = ref(
  TICKET_WAITING_ON_OPTIONS.includes(route.query.waiting_on)
    ? route.query.waiting_on
    : null
);
const currentPage = ref(Number(route.query.page) || 1);

const syncFiltersToUrl = () => {
  router.replace({
    query: {
      ...(statusCategory.value && { status_category: statusCategory.value }),
      ...(ticketType.value && { ticket_type: ticketType.value }),
      ...(overdue.value && { overdue: 'true' }),
      ...(mine.value && { mine: 'true' }),
      ...(customerReplied.value && { customer_replied: 'true' }),
      ...(waitingOn.value && { waiting_on: waitingOn.value }),
      ...(currentPage.value > 1 && { page: currentPage.value }),
    },
  });
};

const fetchTickets = async () => {
  syncFiltersToUrl();
  try {
    await ticketsStore.fetchTickets({
      page: currentPage.value,
      ...(statusCategory.value && { status_category: statusCategory.value }),
      ...(ticketType.value && { ticket_type: ticketType.value }),
      ...(overdue.value && { overdue: true }),
      ...(customerReplied.value && { customer_replied: true }),
      ...(waitingOn.value && { waiting_on: waitingOn.value }),
      ...(mine.value &&
        currentUserId.value && { assignee_id: currentUserId.value }),
    });
  } catch (error) {
    useAlert(error.message);
  }
};

watch(
  [statusCategory, ticketType, overdue, mine, customerReplied, waitingOn],
  () => {
    currentPage.value = 1;
    fetchTickets();
  }
);

// Each chip owns one filter, so a second click on it always means "undo".
const ATTENTION_TOGGLES = {
  triage: () => {
    statusCategory.value = statusCategory.value === 'triage' ? null : 'triage';
  },
  overdue: () => {
    overdue.value = !overdue.value;
  },
  customerReplied: () => {
    customerReplied.value = !customerReplied.value;
  },
  mine: () => {
    mine.value = !mine.value;
  },
  waitingCustomer: () => {
    waitingOn.value = waitingOn.value === 'customer' ? null : 'customer';
  },
};

const activeAttentionKeys = computed(() =>
  [
    statusCategory.value === 'triage' && 'triage',
    overdue.value && 'overdue',
    customerReplied.value && 'customerReplied',
    mine.value && 'mine',
    waitingOn.value === 'customer' && 'waitingCustomer',
  ].filter(Boolean)
);

const onPageChange = page => {
  currentPage.value = page;
  fetchTickets();
};

const openTicket = ticket => {
  router.push({
    name: 'inbox_conversation',
    params: {
      accountId: accountId.value,
      conversation_id: ticket.conversationId,
    },
  });
};

onMounted(() => {
  fetchTickets();
  store.dispatch('ticketCounts/fetch');
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header class="shrink-0">
      <div class="w-full px-6 pt-6">
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ t('TICKETS.HEADER') }}
        </h1>
      </div>
      <TicketsAttentionStrip
        :counts="ticketCounts"
        :active-keys="activeAttentionKeys"
        class="px-6 mt-5"
        @toggle="ATTENTION_TOGGLES[$event]()"
      />
      <TicketsFilterBar
        v-model:status-category="statusCategory"
        v-model:ticket-type="ticketType"
        v-model:overdue="overdue"
        v-model:mine="mine"
        class="pb-4 mx-6 mt-4 border-b border-n-weak"
      />
    </header>
    <main class="flex-1 min-w-0 px-6 overflow-y-auto">
      <TicketsTable
        :tickets="tickets"
        :is-loading="isFetching"
        :no-data-message="t('TICKETS.EMPTY_STATE')"
        @open="openTicket"
      />
    </main>
    <footer v-if="tickets.length" class="sticky bottom-0 shrink-0">
      <PaginationFooter
        :current-page="currentPage"
        :total-items="meta.count"
        :items-per-page="TICKETS_PER_PAGE"
        @update:current-page="onPageChange"
      />
    </footer>
  </section>
</template>
