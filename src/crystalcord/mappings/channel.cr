require "./util"

module CrystalCord
  struct Message
    Util.wrap msg : Basic::Message

    Util.delegate_alias(
      {:is_tts?, :tts},
      {:mentions_everyone?, :mention_everyone},
      {:is_pinned?, :pinned}, to: @msg
    )

    # Returns an array of `Role`s that were mentioned in the message
    def mentioned_roles
      @msg.mention_roles.map { |id| CrystalCord::Role.new(@cache.resolve_role(id), @client) }
    end

    # Returns the text channel this message was sent to.
    def channel
      CrystalCord::TextChannel.from_discord_object(@cache.resolve_channel(@msg.channel_id), @client)
    end

    # Returns the `Guild` object of this message's channel if it's in a guild.
    def guild
      if channel.is_a?(CrystalCord::GuildChannel)
        guild_id = channel.as(CrystalCord::GuildChannel).guild_id
        CrystalCord::Guild.from_discord_object(@cache.resolve_guild(guild_id), @client)
      end
    end

    # Edit the message.
    # Will raise if the message is not the bot's.
    def edit(new_content : String)
      raise "Can only edit own messages!" if author.id != @cache.resolve_current_user.id
      @client.edit_message(channel_id, id, new_content)
    end

    # Append text to the message.
    # Will ensure spacing between the content and the appended content unless *space* is `false`.
    def append(appended_content : String, space = true)
      new_content = String.build do |str|
        str << content
        str << " " if !({' ', '\t', '\n'}.includes?(content[content.size - 1])) && space
        str << appended_content
      end
      edit(new_content)
    end

    # Prepend text to the message.
    # Will ensure spacing between the content and the appended content unless *space* is `false`.
    def prepend(prepended_content : String, space = true)
      new_content = String.build do |str|
        str << prepended_content
        str << " " if !({' ', '\t', '\n'}.includes?(content[content.size - 1])) && space
        str << content
      end
      edit(new_content)
    end

    # Sends a message in the same channel that this message was received in.
    def respond(msg : String)
      channel.say(msg)
    end

    # Returns the `BasicUser` object of the author.
    def author
      CrystalCord::BasicUser.new(@msg.author, @client)
    end

    # Returns the `GuildMember` object of the author if this message was received in a text channel in a guild.
    def member
      chan = channel
      if chan.is_a? CrystalCord::PublicChannel
        CrystalCord::GuildMember.new(@cache.resolve_member(guild_id: chan.guild_id.not_nil!, user_id: @msg.author.id), @client) if chan.guild_id
      end
    end

    # Returns an array of `BasicUser`s mentioned in the message.
    def mentions
      @msg.mentions.each { |m| CrystalCord::BasicUser.new(m, @client) }
    end

    delegate(
      :type, :content, :id, :channel_id, :timestamp, :attachments, :embeds,
      to: @msg
    )
  end

  enum ChannelType
    GuildText
    Private
    GuildVoice
    Group
  end

  abstract struct Channel
    Util.wrap channel : Basic::Channel

    abstract def id : UInt64
    abstract def name : String

    # Creates a functioning channel mention (link).
    def to_s
      "<##{id}>"
    end

    # ditto
    def to_s(io)
      io << "<#"
      io << id
      io << ">"
    end

    def self.from_discord_object(obj : Basic::Channel, client : CrystalCord::Client)
      obj = obj.is_a?(Basic::PrivateChannel) ? Basic::Channel.new(obj) : obj
      case CrystalCord::ChannelType.new obj.type.to_i32
      when CrystalCord::ChannelType::GuildText
        PublicChannel.new obj, client
      when CrystalCord::ChannelType::Private
        PrivateChannel.new obj, client
      when CrystalCord::ChannelType::GuildVoice
        VoiceChannel.new obj, client
      when CrystalCord::ChannelType::Group
        GroupChannel.new obj, client
      else
        raise "Unknown channel type #{obj.type}!"
      end
    end
  end

  abstract struct TextChannel < Channel
    abstract def last_message_id

    # Returns the last message from this text channel if one exists.
    def last_message
      CrystalCord::Message.new(@client.get_channel_message(channel_id: id, message_id: last_message_id.not_nil!), @client) if id && last_message_id
    end

    # Sends a message to this text channel.
    def say(msg : String)
      Message.new(@client.create_message(@channel.id, msg), @client)
    end

    # Creates a text channel depending on the basic channel object's type
    def self.from_discord_object(obj : Basic::Channel, client : CrystalCord::Client)
      obj = obj.is_a?(Basic::PrivateChannel) ? Basic::Channel.new(obj) : obj
      case CrystalCord::ChannelType.new obj.type.to_i32
      when CrystalCord::ChannelType::GuildText
        PublicChannel.new obj, client
      when CrystalCord::ChannelType::Private
        PrivateChannel.new obj, client
      when CrystalCord::ChannelType::Group
        GroupChannel.new obj, client
      else
        raise "Unknown text channel type #{obj.type}!"
      end
    end
  end

  struct PrivateChannel < TextChannel
    def recipients
      @channel.recipients.not_nil!.map { |u| CrystalCord::BasicUser.new(u, @client) }
    end

    def name
      @channel.recipients.not_nil!.first.username
    end

    delegate(
      :id, :last_message_id,
      to: @channel
    )
  end

  module GuildChannel
    abstract def guild_id
    abstract def guild

    def self.from_discord_object(obj : Basic::Channel, client : CrystalCord::Client)
      obj = obj.is_a?(Basic::PrivateChannel) ? Basic::Channel.new(obj) : obj
      case CrystalCord::ChannelType.new obj.type.to_i32
      when CrystalCord::ChannelType::GuildText
        PublicChannel.new obj, client
      when CrystalCord::ChannelType::GuildVoice
        VoiceChannel.new obj, client
      else
        raise "Unknown text channel type #{obj.type}!"
      end
    end
  end

  struct PublicChannel < TextChannel
    include GuildChannel

    def guild
      CrystalCord::Guild.from_discord_object(@cache.resolve_guild(@channel.guild_id.not_nil!), @client) if @channel.guild_id
    end

    def topic
      @channel.topic || ""
    end

    Util.delegate_not_nil!(
      :name, :guild_id,
      to: @channel
    )

    delegate(
      :id, :permission_overwrites, :last_message_id,
      to: @channel
    )
  end

  struct GroupChannel < TextChannel
    Util.delegate_not_nil!(
      :name,
      to: @channel
    )
    delegate(
      :id, :last_message_id,
      to: @channel
    )
  end

  struct VoiceChannel < Channel
    include GuildChannel

    def guild
      CrystalCord::Guild.from_discord_object(@cache.resolve_guild(@channel.guild_id), @client) if @channel.guild_id
    end

    Util.delegate_not_nil!(
      :bitrate, :user_limit, :name,
      to: @channel
    )
    delegate(
      :id, :permission_overwrites, :guild_id,
      to: @channel
    )
  end
end
