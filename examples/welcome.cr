# This simple example bot creates a message whenever a new user joins the server

require "../src/crystalcord"

# Set the BOT_TOKEN and BOT_CLIENT_ID environment variables with the appropriate values
client = CrystalCord::Client.new(token: "Bot #{ENV["BOT_TOKEN"]}", client_id: ENV["BOT_CLIENT_ID"].to_u64)

client.on_guild_member_add do |payload|
  if payload.guild.text_channels.size > 0
    payload.guild.text_channels.sample.say "Welcome #{payload.user} to #{payload.guild.name}!"
  end
end

client.run
