{Channel, Transport} = require "../src/index"
transport = Transport.Redis.Queue.create()
channel = Channel.create transport, "hello"

channel.emit message: "Hello, World"
