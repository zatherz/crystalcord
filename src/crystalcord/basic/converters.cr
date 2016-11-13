require "json"
require "time/format"

module CrystalCord
  module Basic
    DATE_FORMAT = Time::Format.new("%FT%T.%L%:z")

    # :nodoc:
    module SnowflakeConverter
      def self.from_json(parser : JSON::PullParser) : UInt64
        parser.read_string.to_u64
      end

      def self.to_json(value : UInt64, io : IO)
        io.puts(value.to_s)
      end
    end

    # :nodoc:
    module MaybeSnowflakeConverter
      def self.from_json(parser : JSON::PullParser) : UInt64?
        str = parser.read_string_or_null

        if str
          str.to_u64
        else
          nil
        end
      end

      def self.to_json(value : UInt64?, io : IO)
        if value
          io.puts(value.to_s)
        else
          io.puts("null")
        end
      end
    end

    # :nodoc:
    module SnowflakeArrayConverter
      def self.from_json(parser : JSON::PullParser) : Array(UInt64)
        Array(String).new(parser).map &.to_u64
      end

      def self.to_json(value : Array(UInt64), io : IO)
        value.map(&.to_s).to_json(io)
      end
    end
  end
end
