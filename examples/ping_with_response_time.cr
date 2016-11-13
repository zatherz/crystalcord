# This example is nearly the same as the normal ping example, but rather than simply
# responding with "Pong!", it also responds with the time it took to send the message.

require "../src/crystalcord"

# Set the BOT_TOKEN and BOT_CLIENT_ID environment variables with the appropriate values
client = CrystalCord::Client.new(token: "Bot #{ENV["BOT_TOKEN"]}", client_id: ENV["BOT_CLIENT_ID"].to_u64)

client.on_message_create do |msg|
  if msg.content.starts_with? "Ping!"
    # We first create a new Message, and then we check how long it took to send the message by comparing it to the current time
    m = msg.channel.say("Pong!")
    time = Time.utc_now - m.timestamp
    m.append("Time taken: #{time.total_milliseconds} ms.")
  end
end

client.run
