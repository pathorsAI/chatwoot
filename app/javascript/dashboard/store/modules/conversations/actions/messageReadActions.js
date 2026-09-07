import { throwErrorMessage } from 'dashboard/store/utils/api';
import ConversationApi from '../../../../api/inbox/conversation';
import mutationTypes from '../../../mutation-types';

export default {
  markMessagesRead: async ({ commit, state }, data) => {
    const chat = state.allConversations.find(c => c.id === data.id);
    const previousUnreadCount = chat ? chat.unread_count : 0;
    // Clear the badge right away, the agent is already reading the conversation.
    // `agent_last_seen_at` is updated only after the delay below, so the unread
    // divider stays visible in the open conversation.
    commit(mutationTypes.UPDATE_MESSAGE_UNREAD_COUNT, { id: data.id });
    try {
      const {
        data: { id, agent_last_seen_at: lastSeen },
      } = await ConversationApi.markMessageRead(data);
      setTimeout(
        () =>
          commit(mutationTypes.UPDATE_MESSAGE_UNREAD_COUNT, { id, lastSeen }),
        4000
      );
    } catch (error) {
      commit(mutationTypes.UPDATE_MESSAGE_UNREAD_COUNT, {
        id: data.id,
        unreadCount: previousUnreadCount,
      });
    }
  },

  markMessagesUnread: async ({ commit }, { id }) => {
    try {
      const {
        data: { agent_last_seen_at: lastSeen, unread_count: unreadCount },
      } = await ConversationApi.markMessagesUnread({ id });
      commit(mutationTypes.UPDATE_MESSAGE_UNREAD_COUNT, {
        id,
        lastSeen,
        unreadCount,
      });
    } catch (error) {
      throwErrorMessage(error);
    }
  },
};
