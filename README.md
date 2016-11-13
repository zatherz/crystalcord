[![docs](https://img.shields.io/badge/docs-latest-green.svg?style=flat-square)](https://zatherz.github.io/crystalcord/doc/master/)

# CrystalCord

CrystalCord is a fork of [discordcr](https://github.com/meew0/discordcr).  
It aims to be an easy to use Discord library for Crystal.
Very high performance is not a goal, although the library should be faster than [discordrb](https://github.com/meew0/discordrb) which it tries to somewhat imitate.

If you want to trade higher performance for less ease of use, use [discordcr](https://github.com/meew0/discordrb).
CrystalCord does not officially (at least yet) support selfbots (user accounts), but it's possible that it may work.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  crystalcord:
    github: zatherz/crystalcord
```

## Usage

An example bot can be found
[here](https://github.com/zatherz/crystalcord/blob/master/examples/ping.cr). More
examples can be found [here](https://github.com/zatherz/crystalcord/blob/master/examples).

A short overview of library structure: the `Client` class includes the `REST`
module, which handles the REST parts of Discord's API; the `Client` itself
handles the gateway, i. e. the interactive parts such as receiving messages. It
is possible to use only the REST parts by never calling the `#run` method on a
`Client`, which is what does the actual gateway connection.

CrystalCord wraps JSON response structs in special wrappers that give access to simple shortcut methods.
For example, the `Basic::Message` JSON response struct is wrapped by the `Message` struct to include
the `respond` method (and more).

As opposed to discordcr, CrystalCord creates the cache automatically for you.

API documentation is available at
https://zatherz.github.io/crystalcord/doc/master/.

## Contributing

1. Fork it (https://github.com/zatherz/crystalcord/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [meew0](https://github.com/meew0) - creator and maintainer of discordcr
- [RX14](https://github.com/RX14) - Crystal expert, maintainer of discordcr
- [zatherz](https://github.com/zatherz) - creator and maintainer of CrystalCord
