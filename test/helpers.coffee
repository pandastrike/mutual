{inspect} = require "util"
Channel = require "../src/channel"
events = new Channel
# events.receive (message) =>
#   {event,content} = message
#   return if event.match /verbose$/
#   content = (inspect content).replace(/\s+/g, " ")
#   if content?.length > 40
#     content = content[0..39] + " ..."
#   console.log "EVENT", "[#{event}]", "[#{content}]"

module.exports =
  testify: require "testify"
  assert: require "assert"
  events: events
    