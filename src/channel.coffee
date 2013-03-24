{type,overload} = require "fairmont"
setImmediate = process.nextTick unless setImmediate?


class Channel
  
  constructor: ->
    @handlers = []
  
  send: (args...) ->
    setImmediate => @fire args...
  
  fire: (message) ->
    @package message
    for handler in @handlers
      handler message

  receive: (handler) ->
    @handlers.push handler
    
  remove: (handler) ->
    keepers = []
    for _handler in @handlers
      unless _handler is handler
        keepers.push _handler
    @handlers = keepers
    
  forward: (channel) ->
    @receive (message) =>
      channel.fire message
    
  source: (block) ->
    channel = new @constructor
    channel.forward @
    (block channel) if block?
    channel    
    
  package: (message) ->
    message
    
module.exports = Channel