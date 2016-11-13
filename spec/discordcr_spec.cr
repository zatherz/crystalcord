require "yaml"
require "./spec_helper"

struct StructWithSnowflake
  JSON.mapping(
    data: {type: UInt64, converter: CrystalCord::Basic::SnowflakeConverter}
  )
end

struct StructWithMaybeSnowflake
  JSON.mapping(
    data: {type: UInt64?, converter: CrystalCord::Basic::MaybeSnowflakeConverter}
  )
end

struct StructWithSnowflakeArray
  JSON.mapping(
    data: {type: Array(UInt64), converter: CrystalCord::Basic::SnowflakeArrayConverter}
  )
end

describe CrystalCord do
  describe "VERSION" do
    it "matches shards.yml" do
      version = YAML.parse(File.read(File.join(__DIR__, "..", "shard.yml")))["version"].as_s
      version.should eq(CrystalCord::VERSION)
    end
  end

  describe CrystalCord::Basic::SnowflakeConverter do
    it "converts a string to u64" do
      json = %({"data":"10000000000"})

      obj = StructWithSnowflake.from_json(json)
      obj.data.should eq 10000000000
      obj.data.should be_a UInt64
    end
  end

  describe CrystalCord::Basic::MaybeSnowflakeConverter do
    it "converts a string to u64" do
      json = %({"data":"10000000000"})

      obj = StructWithMaybeSnowflake.from_json(json)
      obj.data.should eq 10000000000
      obj.data.should be_a UInt64
    end

    it "converts null to nil" do
      json = %({"data":null})

      obj = StructWithMaybeSnowflake.from_json(json)
      obj.data.should eq nil
    end
  end

  describe CrystalCord::Basic::SnowflakeArrayConverter do
    it "converts an array of strings to u64s" do
      json = %({"data":["1", "2", "10000000000"]})

      obj = StructWithSnowflakeArray.from_json(json)
      obj.data.should be_a Array(UInt64)
      obj.data[0].should eq 1
      obj.data[1].should eq 2
      obj.data[2].should eq 10000000000
    end
  end
end
