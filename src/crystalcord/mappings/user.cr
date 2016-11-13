require "./util"

module CrystalCord
  abstract struct User
    abstract def name
    abstract def id
    abstract def discriminator
    abstract def avatar
    abstract def email
    abstract def is_bot?

    def to_s
      "<@!#{id}>"
    end

    def to_s(io)
      io << "<@!"
      io << id
      io << ">"
    end
  end

  struct BasicUser < CrystalCord::User
    Util.wrap user : Basic::User

    def member_on(guild : CrystalCord::Guild)
      CrystalCord::GuildMember.new(@cache.resolve_member(guild_id: guild.id, user_id: id), @client)
    end

    def member_on(guild_id : UInt64)
      CrystalCord::GuildMember.new(@cache.resolve_member(guild_id: guild_id, user_id: id), @client)
    end

    Util.delegate_alias(
      {:is_bot?, :bot},
      {:name, :username},
      to: @user
    )

    delegate(
      :id, :discriminator, :avatar, :email,
      to: @user
    )
  end

  # TODO: May be redundant
  # Will remove if it works without
  #
  # struct PartialUser < User
  #   Util.wrap partial : Basic::PartialUser

  #   Util.delegate_alias({:is_bot?, :bot}, to: @partial)

  #   delegate(
  #     :id, :bot, :username, :discriminator, :avatar, :email,
  #     to: @partial
  #   )
  # end
end
