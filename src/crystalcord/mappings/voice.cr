require "./util"

module CrystalCord
  struct VoiceState
    Util.wrap voice_state : Basic::VoiceState

    def guild
      CrystalCord::Guild.from_discord_object(@cache.resolve_guild(@voice_state.guild_id.not_nil!), @client) if @voice_state.guild_id
    end

    def channel
      CrystalCord::VoiceChannel.new(@cache.resolve_channel(@voice_state.channel_id.not_nil!), @client) if @voice_state.channel_id
    end

    def user
      CrystalCord::BasicUser.new(@cache.resolve_user(@voice_state.channel_id.not_nil!), @client) if @voice_state.channel_id
    end

    def member
      CrystalCord::GuildMember.new(@cache.resolve_member(guild_id: @voice_state.guild_id.not_nil!, user_id: @voice_state.user_id), @client) if @voice_state.guild_id
    end

    Util.delegate_alias(
      {:is_deaf?, :deaf},
      {:is_muted?, :mute},
      {:is_self_deaf?, :self_deaf},
      {:is_self_muted?, :self_mute},
      {:is_suppressed?, :suppress},
      to: @voice_state
    )

    delegate(
      :guild_id, :channel_id, :user_id, :session_id,
      to: @voice_state
    )
  end
end
