{promise} = require "when"
assert = require "assert"
Amen = require "amen"
{Channel} = require "../src/index"
{randomKey} = require "key-forge"

Amen.describe "Local Channel", (context) ->

  channel = randomKey 8, "base64url"
  context.test "Send and receive a message (channel: #{channel})", ->

    client = Channel.create channel

    message = promise (resolve, reject) ->
      client.on message: (content) ->
        resolve content

    server = Channel.create channel
    server.emit message: "Hello, World"

    client.close()
    server.close()

    assert (yield message) == "Hello, World"
