{type,overload} = require "fairmont"
setImmediate = process.nextTick unless setImmediate?

class Channel
  
  # @property [Array] handlers
  handlers: []

  constructor: ->
  
  send: (args...) ->
    setImmediate => @fire args...
  
  fire: (message) ->
    @package message
    for handler in @handlers
      handler message

  receive: (handler) ->
    @handlers.push handler
    
  remove: (handler) ->
    @handlers = (for _handler in @handlers when _handler isnt handlers)
    
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