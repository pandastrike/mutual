The set up for our client is much like that for the server. We create a Channel, as before, only this time we use a Remote Transport.

    {Channel, Transport} = require "../src/index"
    transport = Transport.Redis.Queue.create()
    channel = Channel.create "hello", transport

All our client does is send a message to the server.

    channel.emit message: "Hello, World"

Since we're not doing anything else in this simple example, we're ready to exit, which means we should close the channel.

    channel.close()

Make sure you have Redis running on port 6379!
