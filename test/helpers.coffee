{inspect} = require "util"
module.exports =
  testify: require "testify"
  assert: require "assert"
  remote: ->
    EventChannel = require "../src/event-channel"
    Transport = require "../src/redis-transport"
    events = new EventChannel
    events.receive (message) =>
      # {event,content} = message
      # return if event.match /verbose$/
      # content = (inspect content).replace(/\s+/g, " ")
      # if content?.length > 40
      #   content = content[0..39] + " ..."
      # console.log "EVENT", "[#{event}]", "[#{content}]"
    
    options:
      events: events
      name: "greeting"
      transport: new Transport 
        host: "localhost"
        port: 6379
        events: events
    