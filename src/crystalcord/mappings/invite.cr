require "./util"

module CrystalCord
  struct Invite
    Util.wrap invite : Basic::Invite

    def guild
      CrystalCord::InviteGuild.new(@invite.guild, @client)
    end

    delegate(
      :code, :channel,
      to: @invite
    )
  end

  struct InviteMetadata
    Util.wrap metadata : Basic::InviteMetadata

    def guild
      CrystalCord::InviteGuild.new(@metadata.guild, @client)
    end

    def inviter
      CrystalCord::BasicUser.new(@metadata.user, @client)
    end

    Util.delegate_alias({:is_temporary?, :temporary},
      {:is_revoked?, :revoked},
      {:user_count, :users},
      to: @metadata)

    delegate(
      :code, :channel, :max_uses, :max_age, :temporary, :created_at, :revoked,
      to: @invite
    )
  end

  struct InviteGuild
    Util.wrap invite_guild : Basic::InviteGuild

    delegate(
      :id, :name, :splash_hash,
      to: @invite_guild
    )
  end
end
