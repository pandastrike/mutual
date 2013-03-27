Channel = require "../src/channel"
helpers = require "./helpers"
{testify, assert} = helpers

channel = new Channel

testify.test "A channel", (context) ->

  channel.send content: "hello"

  channel.receive (message) =>
    context.test "can send and receive events", ->
      assert.ok message.content is "hello"
