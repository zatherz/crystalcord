require "http/web_socket"
require "json"

require "./logger"
require "./rest"
require "./cache"
require "./mappings/*"
require "./basic/*"

module CrystalCord
  # The basic client class that is used to connect to Discord, send REST
  # requests, or send or receive gateway messages. It is required for doing any
  # sort of interaction with Discord.
  #
  # A new simple client that does nothing yet can be created like this:
  # ```
  # client = CrystalCord::Client.new(token: "Bot token", client_id: 123_u64)
  # ```
  #
  # With this client, REST requests can now be sent. (See the `CrystalCord::REST`
  # module.) A gateway connection can also be started using the `#run` method.
  class Client
    include REST

    # The data in the cache will be updated as the client
    # receives the corresponding gateway dispatches.
    setter cache : Cache?

    def cache
      @cache ||= Cache.new(self)
    end

    @websocket : HTTP::WebSocket

    # Default analytics properties sent in IDENTIFY
    DEFAULT_PROPERTIES = Basic::Gateway::IdentifyProperties.new(
      os: "Crystal",
      browser: "CrystalCord",
      device: "CrystalCord",
      referrer: "",
      referring_domain: ""
    )

    # Creates a new bot with the given *token* and *client_id*. Both of these
    # things can be found on a bot's application page; the token will need to be
    # revealed using the "click to reveal" thing on the token (**not** the
    # OAuth2 secret!)
    #
    # If the *shard* key is set, the gateway will operate in sharded mode. This
    # means that this client's gateway connection will only receive packets from
    # a part of the guilds the bot is connected to. See
    # [here](https://discordapp.com/developers/docs/topics/gateway#sharding)
    # for more information.
    #
    # The *large_threshold* defines the minimum member count that, if a guild
    # has at least that many members, the client will only receive online
    # members in GUILD_CREATE. The default value 100 is what the Discord client
    # uses; the maximum value is 250. To get a list of offline members as well,
    # the `#request_guild_members` method can be used.
    #
    # If *compress* is true, packets will be sent in a compressed manner.
    # CrystalCord doesn't currently handle packet decompression, so until that is
    # implemented, setting this to true will cause the client to fail to parse
    # anything.
    #
    # The *properties* define what values are sent to Discord as analytics
    # properties. It's not recommended to change these from the default values,
    # but if you desire to do so, you can.
    def initialize(@token : String, @client_id : UInt64,
                   @shard : Gateway::ShardKey? = nil,
                   @large_threshold : Int32 = 100,
                   @compress : Bool = false,
                   @properties : Gateway::IdentifyProperties = DEFAULT_PROPERTIES)
      @websocket = initialize_websocket
      @backoff = 1.0
    end

    # Connects this client to the gateway. This is required if the bot needs to
    # do anything beyond making REST API calls. Calling this method will block
    # execution until the bot is forcibly stopped.
    def run
      @reconnect = true
      loop do
        begin
          @websocket.run
        rescue ex
          LOGGER.error <<-LOG
            Received exception from WebSocket#run:
            #{ex}
            LOG
        end

        break if !@reconnect
        wait_for_reconnect

        LOGGER.info "Reconnecting"
        @websocket = initialize_websocket
      end
    end

    def stop
      LOGGER.info "Requested client stop"
      @reconnect = false
      @websocket.close
    end

    # Separate method to wait an ever-increasing amount of time before reconnecting after being disconnected in an
    # unexpected way
    def wait_for_reconnect
      # Wait before reconnecting so we don't spam Discord's servers.
      LOGGER.debug "Attempting to reconnect in #{@backoff} seconds."
      sleep @backoff.seconds

      # Calculate new backoff
      @backoff = 1.0 if @backoff < 1.0
      @backoff *= 1.5
      @backoff = 115 + (rand * 10) if @backoff > 120 # Cap the backoff at 120 seconds and then add some random jitter
    end

    private def initialize_websocket : HTTP::WebSocket
      url = URI.parse(get_gateway.url)
      websocket = HTTP::WebSocket.new(
        host: url.host.not_nil!,
        path: "#{url.path}/?encoding=json&v=6",
        port: 443,
        tls: true
      )

      websocket.on_message(&->on_message(String))
      websocket.on_close(&->on_close(String))

      websocket
    end

    private def on_close(message : String)
      # TODO: make more sophisticated
      LOGGER.warn "Closed with: " + message

      @session.try &.suspend
      nil
    end

    OP_DISPATCH              =  0
    OP_HEARTBEAT             =  1
    OP_IDENTIFY              =  2
    OP_STATUS_UPDATE         =  3
    OP_VOICE_STATE_UPDATE    =  4
    OP_VOICE_SERVER_PING     =  5
    OP_RESUME                =  6
    OP_RECONNECT             =  7
    OP_REQUEST_GUILD_MEMBERS =  8
    OP_INVALID_SESSION       =  9
    OP_HELLO                 = 10
    OP_HEARTBEAT_ACK         = 11

    private def on_message(message : String)
      spawn do
        packet = parse_message(message)

        begin
          case packet.opcode
          when OP_HELLO
            payload = Basic::Gateway::HelloPayload.from_json(packet.data)
            handle_hello(payload.heartbeat_interval)
          when OP_DISPATCH
            handle_dispatch(packet.event_type, packet.data)
          when OP_RECONNECT
            handle_reconnect
          when OP_INVALID_SESSION
            handle_invalid_session
          when OP_HEARTBEAT
            # We got a received heartbeat, reply with the same sequence
            LOGGER.debug "Heartbeat received"
            @websocket.send({op: 1, d: packet.sequence}.to_json)
          when OP_HEARTBEAT_ACK
            LOGGER.debug "Heartbeat ACK"
          else
            LOGGER.warn "Unsupported message: #{message}"
          end
        rescue ex : JSON::ParseException
          LOGGER.error <<-LOG
            An exception occurred during message parsing! Please report this.
            #{ex}
            (pertaining to previous exception) Raised with packet:
            #{message}
            LOG
        rescue ex
          LOGGER.error <<-LOG
            A miscellaneous exception occurred during message handling.
            #{ex}
            LOG
        end

        # Set the sequence to confirm that we have handled this packet, in case
        # we need to resume
        seq = packet.sequence
        @session.try &.sequence = seq if seq
      end

      nil
    end

    # Injects a JSON *message* into the packet handler. Must be a valid gateway
    # packet, including opcode, sequence and type.
    def inject(message)
      on_message(message)
    end

    private def parse_message(message : String)
      parser = JSON::PullParser.new(message)

      opcode = nil
      sequence = nil
      event_type = nil
      data = MemoryIO.new

      parser.read_object do |key|
        case key
        when "op"
          opcode = parser.read_int
        when "d"
          # Read the raw JSON into memory
          parser.read_raw(data)
        when "s"
          sequence = parser.read_int_or_null
        when "t"
          event_type = parser.read_string_or_null
        else
          # Unknown field
          parser.skip
        end
      end

      # Rewind to beginning of JSON
      data.rewind

      Gateway::GatewayPacket.new(opcode, sequence, data, event_type)
    end

    private def handle_hello(heartbeat_interval)
      setup_heartbeats(heartbeat_interval)

      # If it seems like we can resume, we will - worst case we get an op9
      if @session.try &.should_resume?
        resume
      else
        identify
      end
    end

    private def setup_heartbeats(heartbeat_interval)
      spawn do
        loop do
          LOGGER.debug "Sending heartbeat"

          seq = @session.try &.sequence || 0
          @websocket.send({op: 1, d: seq}.to_json)

          sleep heartbeat_interval.milliseconds
        end
      end
    end

    private def identify
      if shard = @shard
        shard_tuple = shard.values
      end

      packet = Basic::Gateway::IdentifyPacket.new(@token, @properties, @compress, @large_threshold, shard_tuple)
      @websocket.send(packet.to_json)
    end

    # Sends a resume packet from the given *sequence* number, or alternatively
    # the current session's last received sequence if none is given. This will
    # make Discord replay all events since that sequence.
    def resume(sequence : Int64? = nil)
      session = @session.not_nil!
      sequence ||= session.sequence

      packet = Basic::Gateway::ResumePacket.new(@token, session.session_id, sequence)
      @websocket.send(packet.to_json)
    end

    # Sends a status update to Discord. By setting the *idle_since* time to
    # something other than `nil`, the client will appear as idle; by setting
    # the *game* to a GamePlaying object the client can be set to appear as
    # playing or streaming a game.
    def status_update(idle_since : Int64? = nil, game : GamePlaying? = nil)
      packet = Basic::Gateway::StatusUpdatePacket.new(idle_since, game)
      @websocket.send(packet.to_json)
    end

    # Sends a voice state update to Discord. This will create a new voice
    # connection on the given *guild_id* and *channel_id*, update an existing
    # one with new *self_mute* and *self_deaf* status, or disconnect from voice
    # if the *channel_id* is `nil`.
    #
    # CrystalCord doesn't support sending or receiving any data from voice
    # connections yet - this will have to be done externally until that happens.
    def voice_state_update(guild_id : UInt64, channel_id : UInt64?, self_mute : Bool, self_deaf : Bool)
      packet = Basic::Gateway::VoiceStateUpdatePacket.new(guild_id, channel_id, self_mute, self_deaf)
      @websocket.send(packet.to_json)
    end

    # Requests a full list of members to be sent for a specific guild. This is
    # necessary to get the entire members list for guilds considered large (what
    # is considered large can be changed using the large_threshold parameter
    # in `#initialize`).
    #
    # The list will arrive in the form of GUILD_MEMBERS_CHUNK dispatch events,
    # which can be listened to using `#on_guild_members_chunk`. If a cache
    # is set up, arriving members will be cached automatically.
    def request_guild_members(guild_id : UInt64, query : String = "", limit : Int32 = 0)
      packet = Basic::Gateway::RequestGuildMembersPacket.new(guild_id, query, limit)
      @websocket.send(packet.to_json)
    end

    # :nodoc:
    macro call_event(name, payload)
      @on_{{name}}_handlers.try &.each do |handler|
        begin
          handler.call({{payload}})
        rescue ex
          LOGGER.error <<-LOG
            An exception occurred in a user-defined event handler!
            #{ex}
            LOG
        end
      end
    end

    # :nodoc:
    macro cache(object)
      cache.try &.cache {{object}}
    end

    macro wrap(type, id)
      CrystalCord::{{type.id}}.new({{id.id}}, self)
    end

    private def handle_dispatch(type, data)
      case type
      when "READY"
        payload = Basic::Gateway::ReadyPayload.from_json(data)

        @session = Gateway::Session.new(payload.session_id)

        # Reset the backoff, because READY means we successfully achieved a
        # connection and don't have to wait next time
        @backoff = 1.0

        cache.cache_current_user(payload.user)

        payload.private_channels.each do |channel|
          cache Basic::Channel.new(channel)

          if channel.type == 1 # DM channel, not group
            recipient_id = channel.recipients[0].id
            cache.cache_dm_channel(channel.id, recipient_id)
          end
        end

        LOGGER.info "Received READY, v: #{payload.v}"
        call_event ready, wrap(Gateway::ReadyPayload, payload)
      when "RESUMED"
        payload = Basic::Gateway::ResumedPayload.from_json(data)
        call_event resumed, payload
      when "CHANNEL_CREATE"
        payload = Basic::Channel.from_json(data)

        cache payload
        guild_id = payload.guild_id
        recipients = payload.recipients
        if guild_id
          @cache.try &.add_guild_channel(guild_id, payload.id)
        elsif payload.type == 1 && recipients
          @cache.try &.cache_dm_channel(payload.id, recipients[0].id)
        end

        call_event channel_create, Channel.from_discord_object(payload, self)
      when "CHANNEL_UPDATE"
        payload = Basic::Channel.from_json(data)

        cache payload

        call_event channel_update, Channel.from_discord_object(payload, self)
      when "CHANNEL_DELETE"
        payload = Basic::Channel.from_json(data)

        @cache.try &.delete_channel(payload.id)
        guild_id = payload.guild_id
        @cache.try &.remove_guild_channel(guild_id, payload.id) if guild_id

        call_event channel_delete, Channel.from_discord_object(payload, self)
      when "GUILD_CREATE"
        payload = Basic::Gateway::GuildCreatePayload.from_json(data)

        guild = Basic::Guild.new(payload)
        cache guild

        payload.channels.each do |channel|
          channel.guild_id = guild.id
          cache channel
          @cache.try &.add_guild_channel(guild.id, channel.id)
        end

        payload.roles.each do |role|
          cache role
          @cache.try &.add_guild_role(guild.id, role.id)
        end

        call_event guild_create, wrap(Gateway::GuildCreatePayload, payload)
      when "GUILD_UPDATE"
        payload = Basic::Guild.from_json(data)

        cache payload

        call_event guild_update, Guild.from_discord_object(payload, self)
      when "GUILD_DELETE"
        payload = Basic::Gateway::GuildDeletePayload.from_json(data)

        @cache.try &.delete_guild(payload.id)

        call_event guild_delete, wrap(Gateway::GuildDeletePayload, payload)
      when "GUILD_BAN_ADD"
        payload = Basic::Gateway::GuildBanPayload.from_json(data)
        call_event guild_ban_add, wrap(Gateway::GuildBanPayload, payload)
      when "GUILD_BAN_REMOVE"
        payload = Basic::Gateway::GuildBanPayload.from_json(data)
        call_event guild_ban_remove, wrap(Gateway::GuildBanPayload, payload)
      when "GUILD_EMOJI_UPDATE"
        payload = Basic::Gateway::GuildEmojiUpdatePayload.from_json(data)
        call_event guild_emoji_update, wrap(Gateway::GuildEmojiUpdatePayload, payload)
      when "GUILD_INTEGRATIONS_UPDATE"
        payload = Basic::Gateway::GuildIntegrationsUpdatePayload.from_json(data)
        call_event guild_integrations_update, wrap(Gateway::GuildIntegrationsUpdatePayload, payload)
      when "GUILD_MEMBER_ADD"
        payload = Basic::Gateway::GuildMemberAddPayload.from_json(data)

        cache payload.user
        member = Basic::GuildMember.new(payload)
        @cache.try &.cache(member, payload.guild_id)

        call_event guild_member_add, wrap(Gateway::GuildMemberAddPayload, payload)
      when "GUILD_MEMBER_UPDATE"
        payload = Basic::Gateway::GuildMemberUpdatePayload.from_json(data)

        cache payload.user
        @cache.try do |c|
          member = c.resolve_member(payload.guild_id, payload.user.id)
          new_member = Basic::GuildMember.new(member, payload.roles)
          c.cache(new_member, payload.guild_id)
        end

        call_event guild_member_update, wrap(Gateway::GuildMemberUpdatePayload, payload)
      when "GUILD_MEMBER_REMOVE"
        payload = Basic::Gateway::GuildMemberRemovePayload.from_json(data)

        cache payload.user
        @cache.try &.delete_member(payload.guild_id, payload.user.id)

        call_event guild_member_remove, wrap(Gateway::GuildMemberRemovePayload, payload)
      when "GUILD_MEMBERS_CHUNK"
        payload = Basic::Gateway::GuildMembersChunkPayload.from_json(data)

        @cache.try &.cache_multiple_members(payload.members, payload.guild_id)

        call_event guild_members_chunk, wrap(Gateway::GuildMembersChunkPayload, payload)
      when "GUILD_ROLE_CREATE"
        payload = Basic::Gateway::GuildRolePayload.from_json(data)

        cache payload.role
        @cache.try &.add_guild_role(payload.guild_id, payload.role.id)

        call_event guild_role_create, wrap(Gateway::GuildRolePayload, payload)
      when "GUILD_ROLE_UPDATE"
        payload = Basic::Gateway::GuildRolePayload.from_json(data)

        cache payload.role

        call_event guild_role_update, wrap(Gateway::GuildRolePayload, payload)
      when "GUILD_ROLE_DELETE"
        payload = Basic::Gateway::GuildRoleDeletePayload.from_json(data)

        @cache.try &.delete_role(payload.role_id)
        @cache.try &.remove_guild_role(payload.guild_id, payload.role_id)

        call_event guild_role_delete, wrap(Gateway::GuildRoleDeletePayload, payload)
      when "MESSAGE_CREATE"
        payload = Basic::Message.from_json(data)
        call_event message_create, wrap(Message, payload)
      when "MESSAGE_UPDATE"
        payload = Basic::Gateway::MessageUpdatePayload.from_json(data)
        call_event message_update, wrap(Gateway::MessageUpdatePayload, payload)
      when "MESSAGE_DELETE"
        payload = Basic::Gateway::MessageDeletePayload.from_json(data)
        call_event message_delete, wrap(Gateway::MessageDeletePayload, payload)
      when "MESSAGE_DELETE_BULK"
        payload = Basic::Gateway::MessageDeleteBulkPayload.from_json(data)
        call_event message_delete_bulk, wrap(Gateway::MessageDeleteBulkPayload, payload)
      when "PRESENCE_UPDATE"
        payload = Basic::Gateway::PresenceUpdatePayload.from_json(data)

        if payload.user.full?
          member = Basic::GuildMember.new(payload)
          @cache.try &.cache(member, payload.guild_id)
        end

        call_event presence_update, wrap(Gateway::PresenceUpdatePayload, payload)
      when "TYPING_START"
        payload = Basic::Gateway::TypingStartPayload.from_json(data)
        call_event typing_start, wrap(Gateway::TypingStartPayload, payload)
      when "USER_UPDATE"
        payload = Basic::User.from_json(data)
        call_event user_update, wrap(BasicUser, payload)
      when "VOICE_STATE_UPDATE"
        payload = Basic::VoiceState.from_json(data)
        call_event voice_state_update, wrap(VoiceState, payload)
      when "VOICE_SERVER_UPDATE"
        payload = Basic::Gateway::VoiceServerUpdatePayload.from_json(data)
        call_event voice_server_update, wrap(Gateway::VoiceServerUpdatePayload, payload)
      else
        LOGGER.warn "Unsupported dispatch: #{type} #{data}"
      end
    end

    private def handle_reconnect
      # Close the websocket - the reconnection logic will kick in. We want this
      # to happen instantly so set the backoff to 0 seconds
      @backoff = 0.0
      @websocket.close

      # Suspend the session so we 1. resume and 2. don't send heartbeats
      @session.try &.suspend
    end

    private def handle_invalid_session
      @session.try &.invalidate
      identify
    end

    # :nodoc:
    macro event(name, payload_type)
      # @on_{{name}}_handlers : {{payload_type}}
      def on_{{name}}(&handler : {{payload_type}} ->)
        (@on_{{name}}_handlers ||= [] of {{payload_type}} ->) << handler
      end
    end

    # Called when the bot has successfully initiated a session with Discord. It
    # marks the point when gateway packets can be set (e. g. `#status_update`).
    #
    # Note that this event may be called multiple times over the course of a
    # bot lifetime, as it is also called when the client reconnects with a new
    # session.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#ready)
    event ready, Gateway::ReadyPayload

    # Called when the client has successfully resumed an existing connection
    # after reconnecting.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#resumed)
    event resumed, Basic::Gateway::ResumedPayload

    # Called when a channel has been created on a server the bot has access to,
    # or when somebody has started a DM channel with the bot.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#channel-create)
    event channel_create, Channel

    # Called when a channel's properties are updated, like the name or
    # permission overwrites.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#channel-update)
    event channel_update, Channel

    # Called when a channel the bot has access to is deleted. This is not called
    # for other users closing the DM channel with the bot, only for the bot
    # closing the DM channel with a user.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#channel-delete)
    event channel_delete, Channel

    # Called when the bot is added to a guild, a guild unavailable due to an
    # outage becomes available again, or the guild is streamed after READY.
    # To verify that it is the first case, you can check the `unavailable`
    # property in `Gateway::GuildCreatePayload`.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#guild-create)
    event guild_create, Gateway::GuildCreatePayload

    # Called when a guild's properties, like name or verification level, are
    # updated.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#guild-update)
    event guild_update, AvailableGuild

    # Called when the bot leaves a guild or a guild becomes unavailable due to
    # an outage. To verify that it is the former case, you can check the
    # `unavailable` property.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#guild-delete)
    event guild_delete, Gateway::GuildDeletePayload

    # Called when somebody is banned from a guild. A `#on_guild_member_remove`
    # event is also called.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#guild-ban-add)
    event guild_ban_add, Gateway::GuildBanPayload

    # Called when somebody is unbanned from a guild.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#guild-ban-remove)
    event guild_ban_remove, Gateway::GuildBanPayload

    # Called when a guild's emoji are updated.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#guild-emoji-update)
    event guild_emoji_update, Gateway::GuildEmojiUpdatePayload

    # Called when a guild's integrations (Twitch, YouTube) are updated.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#guild-integrations-update)
    event guild_integrations_update, Gateway::GuildIntegrationsUpdatePayload

    # Called when somebody other than the bot joins a guild.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#guild-member-add)
    event guild_member_add, Gateway::GuildMemberAddPayload

    # Called when a member object is updated. This happens when somebody
    # changes their nickname or has their roles changed.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#guild-member-update)
    event guild_member_update, Gateway::GuildMemberUpdatePayload

    # Called when somebody other than the bot leaves a guild.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#guild-member-remove)
    event guild_member_remove, Gateway::GuildMemberRemovePayload

    # Called when Discord sends a chunk of member objects after a
    # `#request_guild_members` call. If a `Cache` is set up, this is handled
    # automatically.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#guild-members-chunk)
    event guild_members_chunk, Gateway::GuildMembersChunkPayload

    # Called when a role is created on a guild.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#guild-role-create)
    event guild_role_create, Gateway::GuildRolePayload

    # Called when a role's properties are updated, for example name or colour.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#guild-role-update)
    event guild_role_update, Gateway::GuildRolePayload

    # Called when a role is deleted.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#guild-role-delete)
    event guild_role_delete, Gateway::GuildRoleDeletePayload

    # Called when a message is sent to a channel the bot has access to. This
    # may be any sort of text channel, no matter private or guild.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#message-create)
    event message_create, Message

    # Called when a message is updated. Most commonly this is done for edited
    # messages, but the event is also sent when embed information for an
    # existing message is updated.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#message-update)
    event message_update, Gateway::MessageUpdatePayload

    # Called when a single message is deleted.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#message-delete)
    event message_delete, Gateway::MessageDeletePayload

    # Called when multiple messages are deleted at once, due to a bot using the
    # bulk_delete endpoint.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#message-delete-bulk)
    event message_delete_bulk, Gateway::MessageDeleteBulkPayload

    # Called when a user updates their status (online/idle/offline), the game
    # they are playing, or their streaming status. Also called when a user's
    # properties (user/avatar/discriminator) are changed.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#presence-update)
    event presence_update, Gateway::PresenceUpdatePayload

    # Called when somebody starts typing in a channel the bot has access to.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#typing-start)
    event typing_start, Gateway::TypingStartPayload

    # Called when the user properties of the bot itself are changed.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#user-update)
    event user_update, User

    # Called when somebody joins or leaves a voice channel, moves to a different
    # one, or is muted/unmuted/deafened/undeafened.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#voice-state-update)
    event voice_state_update, VoiceState

    # Called when a guild's voice server changes. This event is called with
    # the current voice server when initially connecting to voice, and it is
    # called again with the new voice server when the current server fails over
    # to a new one, or when the guild's voice region changes.
    #
    # [API docs for this event](https://discordapp.com/developers/docs/topics/gateway#voice-server-update)
    event voice_server_update, Gateway::VoiceServerUpdatePayload
  end

  module Gateway
    alias ShardKey = {shard_id: Int32, num_shards: Int32}

    # :nodoc:
    struct GatewayPacket
      getter opcode, sequence, data, event_type

      def initialize(@opcode : Int64?, @sequence : Int64?, @data : MemoryIO, @event_type : String?)
      end
    end

    class Session
      getter session_id
      property sequence

      def initialize(@session_id : String)
        @sequence = 0_i64

        @suspended = false
        @invalid = false
      end

      def suspend
        @suspended = true
      end

      def suspended? : Bool
        @suspended
      end

      def invalidate
        @invalid = true
      end

      def invalid? : Bool
        @invalid
      end

      def should_resume? : Bool
        suspended? && !invalid?
      end
    end
  end
end
