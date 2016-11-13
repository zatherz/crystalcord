require "./util"
require "./user"

module CrystalCord
  enum VerificationLevel
    None
    Low
    Medium
    High
  end

  abstract struct Guild
    abstract def id

    def self.from_discord_object(guild : Basic::Guild, client : CrystalCord::Client)
      AvailableGuild.new guild, client
    end

    def self.from_discord_object(guild : Basic::UnavailableGuild, client : CrystalCord::Client)
      UnavailableGuild.new guild, client
    end
  end

  abstract struct Guild
    abstract def id

    def self.from_discord_object(guild : Basic::Guild, client : CrystalCord::Client)
      AvailableGuild.new guild, client
    end

    def self.from_discord_object(guild : Basic::UnavailableGuild, client : CrystalCord::Client)
      UnavailableGuild.new guild, client
    end
  end

  struct AvailableGuild < Guild
    Util.wrap guild : Basic::Guild

    def afk_channel
      CrystalCord::Channel.from_discord_object(@cache.resolve_channel(afk_channel_id.not_nil!), @client) if afk_channel_id
    end

    def embed_channel
      CrystalCord::Channel.from_discord_object(@cache.resolve_channel(embed_channel_id.not_nil!), @client) if embed_channel_id
    end

    def verification_level
      VerificationLevel.new(@guild.verification_level.to_i32)
    end

    def channels
      @cache.guild_channels(id).map { |id| CrystalCord::GuildChannel.from_discord_object(@cache.resolve_channel(id), @client) }
    end

    def text_channels
      text_chans = [] of CrystalCord::PublicChannel
      channels.each do |c|
        text_chans << c if c.is_a? CrystalCord::PublicChannel
      end
      text_chans
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
          c = obj
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

    def owner
      CrystalCord::BasicUser.new(@cache.resolve_user(@guild.owner_id), @client)
    end

    def emoji
      @guild.emoji.map { |e| CrystalCord::Emoji.new(e, @client) }
    end

    {% unless flag?(:correct_english) %}
      def emojis
        emoji
      end
    {% end %}

    Util.delegate_alias({:embed_enabled?, :embed_enabled}, to: @guild)

    def roles
      @guild.roles.map { |r| CrystalCord::Role.new(r, @client) }
    end

    delegate(
      :id, :name, :owner_id, :region, :afk_channel_id, :afk_timeout,
      :embed_channel_id, :features, :icon, :splash,
      to: @guild
    )
  end

  struct UnavailableGuild < Guild
    Util.wrap guild : Basic::UnavailableGuild
    delegate(
      :id,
      to: guild
    )
  end

  struct GuildMember < CrystalCord::User
    Util.wrap member : Basic::GuildMember

    def user
      CrystalCord::BasicUser.new(@member.user, @client)
    end

    def roles
      @member.roles.map { |r| CrystalCord::Role.new(@cache.resolve_role(r), @client) }
    end

    Util.delegate_alias(
      {:is_deaf?, :deaf},
      {:is_muted?, :mute},
      to: @member
    )

    delegate(
      :id, :discriminator, :avatar, :email, :is_bot?, :name,
      to: user
    )

    delegate(
      :joined_at, :nick,
      to: @member
    )
  end

  struct Emoji
    Util.wrap emoji : Basic::Emoji

    Util.delegate_alias({:requires_colons?, :require_colons},
      {:is_managed?, :managed},
      to: @emoji)

    def to_s
      "<:#{name}:#{id}>"
    end

    def roles
      @emoji.roles.each { |r| CrystalCord::Role.new(@cache.resolve_role(r), @client) }
    end

    delegate(
      :id, :name,
      to: @emoji
    )
  end

  struct Role
    struct Color
      getter r : UInt8
      getter g : UInt8
      getter b : UInt8

      def initialize(@r, @g, @b)
      end

      def initialize(value : Int)
        @r = ((value >> 16) & 255).to_u8
        @g = ((value >> 8) & 255).to_u8
        @b = (value & 255).to_u8
      end

      def to_i
        @r << 16 | @g << 8 | @b
      end

      {% unless flag?(:correct_english) %}
        def color
          colour
        end
      {% end %}

      def to_s
        "(#{@r}, #{@g}, #{@b})"
      end

      def to_s(io)
        io << "("
        io << @r
        io << ", "
        io << @g
        io << ", "
        io << @b
        io << ")"
      end
    end

    Util.wrap role : Basic::Role

    Util.delegate_alias({:is_hoisted?, :hoist},
      {:is_managed?, :managed},
      {:is_mentionable?, :mentionable},
      to: @role)

    def color
      Color.new(@role.colour)
    end

    def to_s
      "<@&#{id}>"
    end

    def to_s
      "(#{@r}, #{@g}, #{@b})"
    end

    def to_s(io)
      io << "("
      io << @r
      io << ", "
      io << @g
      io << ", "
      io << @b
      io << ")"
    end
  end

  struct Role
    Util.wrap role : Basic::Role

    Util.delegate_alias({:is_hoisted?, :hoist},
      {:is_managed?, :managed},
      {:is_mentionable?, :mentionable},
      to: @role)

    def color
      Color.new(@role.colour)
    end

    def to_s
      "<@&#{id}>"
    end

    def to_s(io)
      io << "<@&"
      io << id
      io << ">"
    end

    Util.alias colour, color

    delegate(
      :id, :name, :permissions, :position,
      to: @role
    )
  end
end
