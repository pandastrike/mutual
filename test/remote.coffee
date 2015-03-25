{promise} = require "when"
assert = require "assert"
Amen = require "amen"
{Channel, Transport} = require "../src/index"
{randomKey} = require "key-forge"

Amen.describe "Remote Channel", (context) ->

  channel = randomKey 8, "base64url"
  context.test "Send and receive a message via queue (channel: #{channel})", ->

    client = Channel.create channel, Transport.Redis.Queue.create()

    message = promise (resolve, reject) ->
      client.on message: (content) ->
        resolve content

    server = Channel.create channel, Transport.Redis.Queue.create()
    server.emit message: "Hello, World"

    assert (yield message) == "Hello, World"

    client.close()
    server.close()


  channel = randomKey 8, "base64url"
  context.test "Send and receive a message
    via broadcast (channel: #{channel})", ->

    client = Channel.create channel, Transport.Redis.Broadcast.create()

    message = promise (resolve, reject) ->
      client.on message: (content) ->
        resolve content

    server = Channel.create channel, Transport.Redis.Broadcast.create()
    server.emit message: "Hello, World"

    assert (yield message) == "Hello, World"

    client.close()
    server.close()
