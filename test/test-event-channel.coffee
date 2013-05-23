EventChannel = require "../src/event-channel"
helpers = require "./helpers"
{testify, assert} = helpers

testify.test "An event channel", (context) ->

  context.test "can send and receive events", (context) ->

    channel = new EventChannel

    channel.emit "hello", "Dan"

    channel.on "hello", (message) =>
      context.test "using an 'on' handler", ->
        assert.ok message is "Dan"
