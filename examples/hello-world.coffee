{Channel} = require "../src/index"
channel = Channel.create "hello"

channel.on message: (message) ->
  assert message == "Hello, World"

channel.emit message: "Hello, World"
