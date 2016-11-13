require "logger"

# The logger class is monkey patched to have a property for the IO.
class Logger
  property io
end

module CrystalCord
  # The built in logger.
  LOGGER = Logger.new(STDOUT)
  LOGGER.progname = "CrystalCord"
end
