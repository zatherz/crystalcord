require "./util"

module CrystalCord
  module Gateway
    struct ReadyPayload
      Util.wrap payload : Basic::Gateway::ReadyPayload

      Util.delegate_alias({:version, :v}, to: @payload)

      def user
        CrystalCord::BasicUser.new(@payload.user, @client)
      end

      def private_channels
        @payload.private_channels.map { |c| CrystalCord::PrivateChannel.new(Basic::Channel.new(c), @client) }
      end

      def guilds
        @payload.guilds.map { |g| CrystalCord::UnavailableGuild.from_discord_object(g, @client) }
      end

      delegate(
        :session_id,
        to: @payload
      )
    end

    struct IdentifyPayload
      Util.wrap payload : Basic::Gateway::IdentifyPayload

      delegate(
        :token, :properties, :compress, :large_threshold, :shard,
        to: @payload
      )
    end

    struct VoiceStateUpdatePayload
      Util.wrap payload : Basic::Gateway::VoiceStateUpdatePayload

      def guild
        CrystalCord::Guild.from_discord_object(@cache.resolve_guild(payload.guild_id), @client)
      end

      def channel
        CrystalCord::VoiceChannel.new(@cache.resolve_channel(@payload.channel_id), @client) if @payload.channel_id
      end

      Util.delegate_alias({:mute?, :mute}, {:deaf?, :deaf}, to: @payload)

      delegate(
        :guild_id, :channel_id,
        to: @payload
      )
    end

    struct RequestGuildMembersPayload
      Util.wrap payload : Basic::Gateway::RequestGuildMembersPayload

      def guild
        CrystalCord::Guild.from_discord_object(@cache.resolve_guild(@payload.guild_id), @client)
      end

      delegate(
        :guild_id, :query, :limit,
        to: @payload
      )
    end

    struct GuildCreatePayload
      Util.wrap payload : Basic::Gateway::GuildCreatePayload

      def owner
        CrystalCord::GuildMember.new(@cache.resolve_member(guild_id: id, user_id: owner_id), @client)
      end

      def afk_channel
        CrystalCord::Channel.from_discord_object(@cache.resolve_channel(@payload.afk_channel_id.not_nil!), @client) if @payload.afk_channel_id
      end

      def verification_level
        VerificationLevel.new(@payload.verification_level.to_i32)
      end

      def roles
        @payload.roles.map { |r| CrystalCord::Role.new(r, @client) }
      end

      def emoji
        @payload.emoji.map { |e| CrystalCord::Emoji.new(e, @client) }
      end

      Util.delegate_alias({:large?, :large},
        {:unavailable?, :unavailable}, to: @payload)

      def voice_states
        @payload.voice_states.map { |vs| CrystalCord::VoiceState.new(vs, @client) }
      end

      def members
        @payload.members.map { |m| CrystalCord::GuildMember.new(m, @client) }
      end

      def channel?(id : UInt64)
        chan = @cache.resolve_channel(id)
        if chan
          CrystalCord::Channel.from_discord_object(chan, @client)
        end
      end

      def channel(id : UInt64)
        c = channel? id
        raise "Thank you! But the channel is in another guild!" if !c
        c
      end

      def channel?(name : String)
        chans = @cache.guild_channels(id)
        chan = nil
        chans.each do |c|
          obj = @cache.resolve_channel(c)
          if obj.name == name
            chan = obj
            break
          end
        end
        if chan
          CrystalCord::Channel.from_discord_object(chan, @client)
        end
      end

      def channel(name : String)
        c = channel?(name)
        raise "Channel with name #{name} doesn't exist in this guild!" if !c
        c
      end

      def channels
        @payload.channels.map { |c| CrystalCord::Channel.from_discord_object(c, @client) }
      end

      def text_channels
        text_chans = [] of CrystalCord::PublicChannel
        channels.each do |c|
          text_chans << c if c.is_a? CrystalCord::PublicChannel
        end
        text_chans
      end

      delegate(
        :id, :name, :owner_id, :region, :afk_channel_id, :features,
        :afk_timeout, :icon, :splash, :member_count, :presences,
        to: @payload
      )
    end

    struct GuildDeletePayload
      Util.wrap payload : Basic::Gateway::GuildDeletePayload

      def guild
        CrystalCord::Guild.from_discord_object(@cache.resolve_guild(guild_id), @client)
      end

      Util.delegate_alias({:is_unavailable?, :unavailable}, to: @payload)

      delegate(
        :id,
        to: @payload
      )
    end

    struct GuildBanPayload
      Util.wrap payload : Basic::Gateway::GuildBanPayload

      def user
        CrystalCord::BasicUser.new(@cache.resolve_user(user_id), @client)
      end

      Util.delegate_alias({:user_id, :id}, to: @payload)

      def guild
        CrystalCord::Guild.from_discord_object(@cache.resolve_guild(guild_id), @client)
      end

      delegate(
        :guild_id,
        to: @payload
      )
    end

    struct GuildEmojiUpdatePayload
      Util.wrap payload : Basic::Gateway::GuildEmojiUpdatePayload

      def guild
        CrystalCord::Guild.from_discord_object(@cache.resolve_guild(@payload.guild_id), @client)
      end

      def emoji
        @payload.emoji.map { |e| CrystalCord::Emoji.new(e, @client) }
      end

      delegate(
        :guild_id,
        to: @payload
      )

      {% unless flag?(:correct_english) %}
        def emojis
          emoji
        end
      {% end %}
    end

    struct GuildIntegrationsUpdatePayload
      Util.wrap payload : Basic::Gateway::GuildIntegrationsUpdatePayload

      def guild
        CrystalCord::Guild.from_discord_object(@cache.resolve_guild(@payload.guild_id), @client)
      end

      delegate(
        :guild_id,
        to: @payload
      )
    end

    struct GuildMemberAddPayload
      Util.wrap payload : Basic::Gateway::GuildMemberAddPayload

      def user_id
        @payload.user.id
      end

      def user
        CrystalCord::BasicUser.new(@payload.user, @client)
      end

      def member
        CrystalCord::GuildMember.new(@cache.resolve_member(user_id: user_id, guild_id: @payload.guild_id), @client)
      end

      def guild
        CrystalCord::Guild.from_discord_object(@cache.resolve_guild(@payload.guild_id), @client)
      end

      Util.delegate_alias(
        {:is_deaf?, :deaf},
        {:is_muted?, :mute},
        {:name, :nick},
        to: @payload
      )

      delegate(
        :joined_at, :guild_id,
        to: @payload
      )
    end

    struct GuildMemberUpdatePayload
      Util.wrap payload : Basic::Gateway::GuildMemberUpdatePayload

      def user_id
        @payload.user.id
      end

      def user
        CrystalCord::BasicUser.new(@payload.user, @client)
      end

      def member
        CrystalCord::GuildMember.new(@cache.resolve_member(user_id: user_id, guild_id: @payload.guild_id), @client)
      end

      def roles
        @payload.roles.map { |r| CrystalCord::Role.new(@cache.resolve_role(r), @client) }
      end

      def guild
        CrystalCord::Guild.from_discord_object(@cache.resolve_guild(@payload.guild_id), @client)
      end

      delegate(
        :guild_id,
        to: @payload
      )
    end

    struct GuildMemberRemovePayload
      Util.wrap payload : Basic::Gateway::GuildMemberRemovePayload

      def user_id
        @payload.user.id
      end

      def user
        CrystalCord::BasicUser.new(@payload.user, @client)
      end

      def guild
        CrystalCord::Guild.from_discord_object(@cache.resolve_guild(@payload.guild_id), @client)
      end

      delegate(
        :guild_id,
        to: @payload
      )
    end

    struct GuildMembersChunkPayload
      Util.wrap payload : Basic::Gateway::GuildMembersChunkPayload

      def members
        @payload.members.map { |m| CrystalCord::GuildMember.new(m, @client) }
      end

      def guild
        CrystalCord::Guild.from_discord_object(@cache.resolve_guild(@payload.guild_id), @client)
      end

      delegate(
        :guild_id,
        to: @payload
      )
    end

    struct GuildRolePayload
      Util.wrap payload : Basic::Gateway::GuildRolePayload

      def role
        CrystalCord::Role.new(@payload.role, @client)
      end

      def guild
        CrystalCord::Guild.from_discord_object(@cache.resolve_guild(@payload.guild_id), @client)
      end

      delegate(
        :guild_id,
        to: @payload
      )
    end

    struct GuildRoleDeletePayload
      Util.wrap payload : Basic::Gateway::GuildRoleDeletePayload

      def guild
        CrystalCord::Guild.from_discord_object(@cache.resolve_guild(@payload.guild_id), @client)
      end

      delegate(
        :guild_id, :role_id,
        to: @payload
      )
    end

    enum MessageUpdateType
      Edit
      GroupRecipientAddition
      GroupRecipientRemoval
      GroupCallCreation
      GroupNameUpdate
      GroupIconUpdate
      PinsAdd
    end

    struct MessageUpdatePayload
      Util.wrap payload : Basic::Gateway::MessageUpdatePayload

      def channel
        CrystalCord::TextChannel.from_discord_object(@cache.resolve_channel(@payload.channel_id), @client)
      end

      def author
        CrystalCord::BasicUser.new(@payload.author.not_nil!, @client) if @payload.author
      end

      Util.delegate_alias(
        {:is_tts?, :tts},
        {:mentions_everyone?, :mention_everyone},
        {:is_pinned?, :pinned},
        to: @payload
      )

      def mentions
        @payload.mentions.not_nil!.map { |u| CrystalCord::BasicUser.new(u, @client) } if @payload.mentions
      end

      def respond(msg)
        message.respond(msg)
      end

      def mentioned_roles
        @payload.mention_roles.not_nil!.map { |r| CrystalCord::Role.new(@cache.resolve_role(r), @client) } if @payload.mention_roles
      end

      def message
        CrystalCord::Message.new(@client.get_channel_message(channel_id: @payload.channel_id, message_id: @payload.id), @client)
      end

      def type
        MessageUpdateType.new(@payload.type.not_nil!.to_i32) if @payload.type
      end

      delegate(
        :id, :channel_id, :content, :timestamp,
        to: @payload
      )
    end

    struct MessageDeletePayload
      Util.wrap payload : Basic::Gateway::MessageDeletePayload

      def channel
        CrystalCord::TextChannel.from_discord_object(@cache.resolve_channel(@payload.channel_id), @client)
      end

      delegate(
        :id, :channel_id,
        to: @payload
      )
    end

    struct MessageDeleteBulkPayload
      Util.wrap payload : Basic::Gateway::MessageDeleteBulkPayload

      def channel
        CrystalCord::TextChannel.from_discord_object(@cache.resolve_channel(@payload.channel_id), @client)
      end

      delegate(
        :ids, :channel_id,
        to: @payload
      )
    end

    struct PresenceUpdatePayload
      Util.wrap payload : Basic::Gateway::PresenceUpdatePayload

      def user
        CrystalCord::BasicUser.new(Basic::User.new(@payload.user), @client) if @payload.user.username && @payload.user.discriminator
      end

      def member
        CrystalCord::GuildMember.new(@cache.resolve_member(user_id: @payload.user.id, guild_id: @payload.guild_id), @client)
      end

      def roles
        @payload.roles.map { |r| CrystalCord::Role.new(@cache.resolve_role(r), @client) }
      end

      def guild
        CrystalCord::Guild.from_discord_object(@cache.resolve_guild(@payload.guild_id), @client)
      end

      Util.delegate_alias({:name, :nick}, to: @payload)

      delegate(
        :guild_id, :status, :game,
        to: @payload
      )
    end

    struct TypingStartPayload
      Util.wrap payload : Basic::Gateway::TypingStartPayload

      def channel
        CrystalCord::TextChannel.from_discord_object(@cache.resolve_channel(@payload.channel_id), @client)
      end

      def user
        CrystalCord::BasicUser.new(@cache.resolve_user(@payload.user_id), @client)
      end

      def member
        if channel.is_a? CrystalCord::GuildChannel
          CrystalCord::GuildMember.new(@cache.resolve_member(guild_id: channel.as(CrystalCord::GuildChannel).guild_id, user_id: @payload.user_id), @client)
        end
      end

      delegate(
        :channel_id, :user_id, :timestamp,
        to: @payload
      )
    end

    struct VoiceServerUpdatePayload
      Util.wrap payload : Basic::Gateway::VoiceServerUpdatePayload

      def guild
        CrystalCord::Guild.from_discord_object(@cache.resolve_guild(@payload.guild_id), @client)
      end

      delegate(
        :token, :guild_id, :endpoint,
        to: @payload
      )
    end
  end
end
