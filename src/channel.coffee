setImmediate = process.nextTick unless setImmediate?

class Channel
  
  constructor: ->
    @handlers = []
  
  send: (message) ->
    setImmediate => @fire( message )
  
  fire: (message) ->
    @package message
    for handler in @handlers
      handler message

  receive: (handler) ->
    @handlers.push handler
    
  remove: (handler) ->
    @handlers = (_handler for _handler in @handlers when _handler isnt handler)
    
  forward: (channel) ->
    @receive (message) =>
      channel.fire message
    
  source: (block) ->
    channel = new @constructor
    channel.forward @
    block channel if block?
    channel    
    
  package: (message) ->
    message
    
module.exports = Channel