RemoteChannel = require "../src/remote-channel"
helpers = require "./helpers"
{testify,assert} = helpers
{options} = helpers.remote()

testify.test "A remote channel", (context) ->

  context.test "can send and receive events", (context) ->

    sender = new RemoteChannel options

    receiver = new RemoteChannel options
    receiver.listen()

    receiver.events.on "hello", (message) ->
      context.test "using an 'on' handler", ->
        assert.ok message.content is "Dan"
        receiver.end()

    sender.send event: "hello", content: "Dan"


