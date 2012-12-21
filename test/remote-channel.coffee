RemoteChannel = require "../src/remote-channel"
Transport = require "../src/redis-transport"

options = 
  name: "greeting"
  transport: new Transport 
    host: "localhost"
    port: 6379

sender = new RemoteChannel options
  
receiver = new RemoteChannel options

do (channel=receiver.listen()) ->
  channel.on "hello", (message) ->
    console.log "Hello, #{message.content}"

sender.send event: "hello", content: "Dan"