import { resolveAgentSelection } from '../voiceAgentSelection';

const bots = [
  { id: 7, name: 'Front desk', project_id: 'proj-a' },
  { id: 12, name: 'Reservations', project_id: 'proj-b' },
];

describe('#resolveAgentSelection', () => {
  it('locks onto the bot whose project already answers the number', () => {
    expect(resolveAgentSelection({ project_id: 'proj-b' }, bots)).toEqual({
      mode: 'locked',
      botId: '12',
    });
  });

  it('reports a routed number whose project has no bot in this account', () => {
    expect(resolveAgentSelection({ project_id: 'proj-z' }, bots)).toEqual({
      mode: 'missing',
      botId: '',
    });
  });

  it('leaves the choice free when nothing answers the number yet', () => {
    expect(resolveAgentSelection({ project_id: null }, bots)).toEqual({
      mode: 'free',
      botId: '',
    });
  });

  it('treats a missing project_id like an unrouted number', () => {
    expect(resolveAgentSelection({ id: 'num-1' }, bots)).toEqual({
      mode: 'free',
      botId: '',
    });
  });

  it('leaves the choice free when no number is selected', () => {
    expect(resolveAgentSelection(undefined, bots)).toEqual({
      mode: 'free',
      botId: '',
    });
  });

  it('reports missing when the bots have not loaded yet', () => {
    expect(resolveAgentSelection({ project_id: 'proj-a' })).toEqual({
      mode: 'missing',
      botId: '',
    });
  });
});
