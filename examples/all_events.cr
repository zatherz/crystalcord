# This simple example bot replies to every "!ping" message with "Pong!".

require "../src/crystalcord"

# Set the BOT_TOKEN and BOT_CLIENT_ID environment variables with the appropriate values
client = CrystalCord::Client.new(token: "Bot #{ENV["BOT_TOKEN"]}", client_id: ENV["BOT_CLIENT_ID"].to_u64)

client.on_ready do |v|
  puts "Connected with API version #{v.version}"
  puts "User ID #{v.user.id}"
  puts "#{v.private_channels.size} private channels"
  puts "#{v.guilds.size} guilds"
end

client.on_resumed do |v|
  puts "Resumed"
end

def test_channel(c)
  c.name
  c.id
  c.to_s
  if c.is_a? CrystalCord::TextChannel
    c.last_message
    c.last_message_id
    c.say("Hello")
  end
  case c
  when CrystalCord::PublicChannel
    c.guild
    c.topic
    c.guild_id
    c.permission_overwrites
  when CrystalCord::PrivateChannel
    c.recipients
  when CrystalCord::VoiceChannel
    c.bitrate
    c.user_limit
    c.permission_overwrites
  end
end

client.on_channel_create do |v|
  puts "Channel (type #{v.class}) create: #{v.name}"
  test_channel(v)
end

client.on_channel_update do |v|
  puts "Channel (type #{v.class}) update: #{v.name}"
  test_channel(v)
end

client.on_channel_delete do |v|
  puts "Channel (type #{v.class}) delete: #{v.name}"
  test_channel(v)
end

def test_guild(g)
  g.id
  if !g.is_a?(CrystalCord::UnavailableGuild)
    g.afk_channel
    g.verification_level
    g.channels
    g.text_channels
    puts "Found channel one" if g.channel?("one")
    puts "Found channel 247130261257453569" if g.channel?(247130261257453569_u64)
    g.owner
    g.emoji
    g.roles
    g.name
    g.owner_id
    g.region
    g.afk_channel_id
    g.features
    g.icon
    g.splash
    if g.is_a? CrystalCord::AvailableGuild
      g.embed_enabled?
      g.embed_channel
      g.embed_channel_id
    end
  end
end

client.on_guild_create do |v|
  puts "Guild (type #{v.class}) create #{v.id}"
  test_guild(v)
  v.member_count
  v.presences
end

client.on_guild_update do |v|
  puts "Guild (type #{v.class}) update #{v.id}"
  test_guild(v)
end

client.on_guild_delete do |v|
  puts "Guild (type #{v.class}) delete #{v.id}"
end

def test_guild_ban(b)
  b.user_id
  b.guild_id
  b.guild
  b.user
end

client.on_guild_ban_add do |v|
  puts "Guild ban add #{v.user_id}"
  test_guild_ban(v)
end

client.on_guild_ban_remove do |v|
  puts "Guild ban remove #{v.user_id}"
  test_guild_ban(v)
end

def test_emoji(e)
  e.requires_colons?
  e.is_managed?
  e.to_s
  e.roles
  e.id
  e.name
end

client.on_guild_emoji_update do |v|
  puts "Guild emoji update"
  v.guild
  v.guild_id
  v.emoji.each do |e|
    test_emoji(e)
  end
end

client.on_guild_integrations_update do |v|
  puts "Guild integrations update"
  v.guild
  v.guild_id
end

client.on_guild_member_add do |v|
  v.user_id
  v.user
  v.member
  v.guild
  v.is_deaf?
  v.is_muted?
  v.name
  v.joined_at
  v.guild_id
end

client.on_guild_member_update do |v|
  puts "Guild member update: #{v.user.name}"
  v.user_id
  v.user
  v.member
  v.roles
  v.guild
  v.guild_id
end

client.on_guild_member_remove do |v|
  puts "Guild member remove: #{v.user.name}"
  v.user_id
  v.user
  v.guild
  v.guild_id
end

client.on_guild_members_chunk do |v|
  puts "Guild members chunk"
  v.members
  v.guild
  v.guild_id
end

def test_role(r)
  puts "Role color: #{r.color}"
  r.is_hoisted?
  r.is_managed?
  r.is_mentionable?
  r.id
  r.name
  r.permissions
  r.position
end

client.on_guild_role_create do |v|
  puts "Guild role create on guild #{v.guild_id}"
  v.guild
  v.guild_id
  test_role(v.role)
end

client.on_guild_role_update do |v|
  puts "Guild role update on guild #{v.guild_id}"
  v.guild
  v.guild_id
  test_role(v.role)
end

client.on_guild_role_delete do |v|
  puts "Guild role delete"
  v.guild
  v.guild_id
  v.role_id
end

client.on_message_create do |v|
  puts "Message create"
  v.is_tts?
  v.mentions_everyone?
  v.is_pinned?
  v.mentioned_roles
  v.channel
  v.guild
  v.respond("test") if !v.author.is_bot?
  v.author
  v.member
  v.mentions
  v.type
  v.content
  v.id
  v.timestamp
  v.attachments
  v.embeds
  v.prepend("abc")
  v.edit("abc")
  v.append("abc")
end

client.on_message_update do |v|
  puts "Message update"
  v.channel
  v.author
  v.is_tts?
  v.mentions_everyone?
  v.is_pinned?
  v.mentions
  v.mentioned_roles
  v.message
  v.type
  v.id
  v.channel_id
  v.content
  v.timestamp
  v.respond("update type #{v.type}")
end

client.on_message_delete do |v|
  puts "Message delete"
  v.channel
  v.id
  v.channel_id
end

client.on_message_delete_bulk do |v|
  puts "Message delete bulk"
  v.channel
  v.ids
  v.channel_id
end

client.on_presence_update do |v|
  puts "Presence update"
  v.user
  v.member
  v.roles
  v.guild
  v.guild_id
  v.status
  v.game
  v.name
end

def test_user(u)
  u = u.not_nil!
  if u.is_a? CrystalCord::GuildMember
    u.user
    u.roles
    u.is_deaf?
    u.is_muted?
    u.nick
  elsif u.is_a? CrystalCord::BasicUser
    u.member_on(246713391304015872_u64)
  end
  u.name
  u.id
  u.discriminator
  u.avatar
  u.email
  u.is_bot?
end

client.on_typing_start do |v|
  puts "Typing start"
  v.channel
  v.user
  test_user(v.member)
  v.channel_id
  v.user_id
  v.timestamp
end

client.on_user_update do |v|
  puts "User update"
  test_user(v)
end

client.on_voice_state_update do |v|
  puts "Voice state update"
  v.guild
  v.channel
  v.user
  v.member
  v.is_deaf?
  v.is_muted?
  v.is_self_deaf?
  v.is_self_muted?
  v.is_suppressed?
  v.guild_id
  v.channel_id
  v.user_id
  v.session_id
end

client.on_voice_server_update do |v|
  puts "Voice server update"
  v.guild
  v.token
  v.guild_id
  v.endpoint
end

client.run
