All we're going to do now is move our server code from our original example into a separate file so we can run it in a separate process. We're also going to use a remote Transport instead of the default Local transport.

    {Channel, Transport} = require "../src/index"
    transport = Transport.Redis.Queue.create()
    channel = Channel.create "hello", transport

As before, we're going to pass a promise resolver function into our server so we can verify that it works correctly.

    server = (resolve) ->
      channel.on message: (message) ->
        resolve message

    {promise} = require "when"
    {call} = require "fairmont"

    call ->

      p = promise (resolve) -> server resolve

      assert = require "assert"
      assert (yield p) == "Hello, World"

There is one additional step: we need to close the Channel when we're ready to exit the process.

      channel.close()
