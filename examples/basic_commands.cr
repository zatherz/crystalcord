# This example bot has a very simple command system

require "../src/crystalcord"

# Set the BOT_TOKEN and BOT_CLIENT_ID environment variables with the appropriate values
client = CrystalCord::Client.new(token: "Bot #{ENV["BOT_TOKEN"]}", client_id: ENV["BOT_CLIENT_ID"].to_u64)

commands = {
  "echo"      => ->(args : Array(String), msg : CrystalCord::Message) { args.join(" ") },
  "info"      => ->(args : Array(String), msg : CrystalCord::Message) { "Example CrystalCord bot" },
  "aesthetic" => ->(args : Array(String), msg : CrystalCord::Message) { args.join(" ").split("").join("   ") },
}

PREFIX = "$"
client.on_message_create do |msg|
  if msg.content.starts_with? PREFIX
    content = msg.content[PREFIX.size..msg.content.size] # get the text without the prefix
    args = content.split /\s/
    command = args.shift
    if proc = commands[command]?
      output = proc.call(args, msg)
      msg.respond(output.to_s)
    else
      msg.respond "Command #{command} doesn't exist!"
    end
  end
end

client.run
