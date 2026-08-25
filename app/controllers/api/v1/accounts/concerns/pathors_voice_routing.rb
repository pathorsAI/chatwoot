# A voice inbox only rings if Pathors knows two things: which inbox owns the
# number, and which Pathors project answers on it. The first comes from the
# inbox, the second from the Pathors agent bot behind it — so creating the inbox
# and swapping its bot both have to talk to the phone-number registry.
module Api::V1::Accounts::Concerns::PathorsVoiceRouting
  extend ActiveSupport::Concern

  private

  # Also the gate on the integration itself: the service raises
  # IntegrationNotConnected when the account has no enabled Pathors hook, which
  # is the only way a voice inbox could otherwise be created without one.
  def setup_pathors_voice_routing(channel)
    agent_bot = pathors_answering_bot
    AgentBotInbox.create!(inbox: @inbox, agent_bot: agent_bot)
    Pathors::PhoneNumbersService.new(account: Current.account)
                                .bind(phone_number_id: channel.pathors_phone_number_id, inbox: @inbox,
                                      project_id: agent_bot.pathors_project_id)
  end

  def pathors_answering_bot
    agent_bot = AgentBot.accessible_to(Current.account).find_by(id: params[:agent_bot])
    raise CustomExceptions::Pathors::AgentBotRequired.new({}) if agent_bot.nil? || agent_bot.pathors_project_id.blank?

    agent_bot
  end

  # The assignment lives here because it cannot be separated from the re-route
  # below: an assignment Pathors refuses to route must not be left behind as the
  # bot the dashboard claims is answering the calls.
  def assign_agent_bot_and_reroute_calls
    ActiveRecord::Base.transaction do
      previous_project_id = @inbox.agent_bot&.pathors_project_id
      agent_bot_inbox = @inbox.agent_bot_inbox || AgentBotInbox.new(inbox: @inbox)
      agent_bot_inbox.agent_bot = @agent_bot
      agent_bot_inbox.save!
      reroute_pathors_voice_calls(previous_project_id)
    end
  end

  # Swapping the bot on a voice inbox swaps the project that answers its number,
  # and Pathors only learns that from a re-bind. It is allowed to fail loudly:
  # a half-done swap — Chatwoot showing the new bot while calls still reach the
  # old project — is worse than a swap that was refused.
  def reroute_pathors_voice_calls(previous_project_id)
    return unless @inbox.channel.is_a?(Channel::Voice)

    phone_number_id = @inbox.channel.pathors_phone_number_id
    project_id = @agent_bot.pathors_project_id
    return if phone_number_id.blank? || project_id.blank? || project_id == previous_project_id

    Pathors::PhoneNumbersService.new(account: Current.account)
                                .bind(phone_number_id: phone_number_id, inbox: @inbox, project_id: project_id)
  end
end
