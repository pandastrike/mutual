assert = require "assert"
Amen = require "amen"
Transport = require "../src/transport/redis/queue.coffee"
{randomKey} = require "key-forge"

Amen.describe "Redis Transport", (context) ->

  channel = randomKey 8, "base64url"
  context.test "Send and receive a message (channel: #{channel})", ->
    transport = Transport.create()
    result = yield transport.send channel, "Hello, World"
    message = yield transport.receive channel
    assert message == "Hello, World"
    transport.close()
