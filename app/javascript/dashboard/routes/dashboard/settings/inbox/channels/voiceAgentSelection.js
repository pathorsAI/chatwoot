/**
 * Works out which Pathors agent bot answers a phone number, so the voice inbox
 * wizard can preselect it instead of asking the user to guess.
 *
 * Pathors already knows who picks up: every phone number payload carries the
 * `project_id` of the project currently routed to it (null when nothing
 * answers it yet). Binding a number to a bot from a *different* project is
 * refused with a 409, so the wizard must not offer that choice at all.
 *
 * `project_id` is absent on older Pathors backends; undefined reads as "not
 * routed", which degrades to the plain free-choice select.
 *
 * @param {object|undefined} number - a Pathors phone number payload
 * @param {Array<object>} bots - the account's Pathors agent bots
 * @returns {{ mode: 'locked'|'missing'|'free', botId: string }}
 *   locked  - routed, and the answering project has a bot here: preselect it
 *   missing - routed to a project with no agent bot in this account: dead end
 *   free    - not routed yet: the user picks any bot
 */
export function resolveAgentSelection(number, bots = []) {
  const projectId = number?.project_id;
  if (!projectId) return { mode: 'free', botId: '' };

  const answeringBot = bots.find(bot => bot.project_id === projectId);
  if (!answeringBot) return { mode: 'missing', botId: '' };

  // Select options identify bots by string, agent bot ids are numeric.
  return { mode: 'locked', botId: String(answeringBot.id) };
}
