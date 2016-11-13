# This simple example bot replies to every "Ping!" message with "Pong!".

require "../src/crystalcord"

# Set the BOT_TOKEN and BOT_CLIENT_ID environment variables with the appropriate values
client = CrystalCord::Client.new(token: "Bot #{ENV["BOT_TOKEN"]}", client_id: ENV["BOT_CLIENT_ID"].to_u64)

client.on_message_create do |msg|
  if msg.content.starts_with? "Ping!"
    msg.respond "#{msg.author} Pong!"
  end
end

client.run
