In this example, we're going to use a Local Transport. The only reason you'd use this is for prototyping. We're going to prototype our client and server in a single process, just to make sure we have the logic. Then we'll switch to a remote Transport. If we weren't planning to do this, we'd just use Evie directly, rather than a Channel.

    {Channel} = require "../src/index"

The default Transport is the Local channel, so we don't need to specify it. We do need to specify a name, though.

    channel = Channel.create "hello"

Our “client” will send a message.

    client = -> channel.emit message: "Hello, World"

Here's our “server”, accepting requests.

    server = (resolve) ->
      channel.on message: (message) ->
        resolve message

To test it out, we'll wrap our `server` invocation in a promise, so we can verify that we go the message.

    {promise} = require "when"
    {call} = require "fairmont"

    call ->

      p = promise (resolve) -> server resolve

Of course, we also need to run the client, but there's nothing tricky about that.

      client()

Let's yield to the promise and make sure it resolved as expected.

      assert = require "assert"
      assert (yield p) == "Hello, World"

Now that we've prototyped our client and server, we can move them into separate files, using a remote Transport.
