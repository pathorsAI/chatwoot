export const TICKET_STATUS_CATEGORIES = [
  'triage',
  'in_progress',
  'waiting',
  'done',
  'closed',
];

// A case in either of these is off the team's plate.
export const SETTLED_TICKET_CATEGORIES = ['done', 'closed'];

// Chip colours reuse the dashboard label palette so a case reads the same way a
// conversation status does elsewhere in the app.
export const TICKET_STATUS_CATEGORY_COLORS = {
  triage: 'amber',
  in_progress: 'blue',
  waiting: 'iris',
  done: 'teal',
  closed: 'slate',
};

export const TICKET_WAITING_ON_OPTIONS = [
  'none',
  'customer',
  'internal',
  'external',
];

// `ticket_type` is a free-form column on the backend; these are the values the
// dashboard offers so the type filter can be a picker instead of a text box.
export const TICKET_TYPES = ['question', 'issue', 'request', 'incident'];

export const TICKET_TASK_STATUS = {
  OPEN: 'open',
  DONE: 'done',
};

export const TICKETS_PER_PAGE = 25;

// The attention strip: the slices of the queue that are asking for someone,
// ordered by how loudly. Colour follows the sidebar badges — blue is unowned
// work, ruby is late work, slate is context.
export const TICKET_ATTENTION_CHIPS = [
  {
    key: 'triage',
    i18nKey: 'TRIAGE',
    color: 'blue',
    inactiveVariant: 'outline',
  },
  {
    key: 'overdue',
    i18nKey: 'OVERDUE',
    color: 'ruby',
    inactiveVariant: 'outline',
  },
  {
    key: 'customerReplied',
    i18nKey: 'CUSTOMER_REPLIED',
    color: 'slate',
    inactiveVariant: 'outline',
  },
  { key: 'mine', i18nKey: 'MINE', color: 'slate', inactiveVariant: 'outline' },
  {
    key: 'waitingCustomer',
    i18nKey: 'WAITING_CUSTOMER',
    color: 'slate',
    inactiveVariant: 'ghost',
  },
];
