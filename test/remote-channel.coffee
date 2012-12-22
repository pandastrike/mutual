RemoteChannel = require "../src/remote-channel"
EventChannel = require "../src/event-channel"
Transport = require "../src/redis-transport"

events = new EventChannel

options = 
  name: "greeting"
  transport: new Transport 
    host: "localhost"
    port: 6379
    events: events


sender = new RemoteChannel options
  
receiver = new RemoteChannel options

receiver.listen()

receiver.events.on "hello", (message) ->
  console.log "Hello, #{message.content}"
  receiver.end()

sender.send event: "hello", content: "Dan"