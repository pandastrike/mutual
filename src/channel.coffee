{type,overload} = require "fairmont"


class Channel
  
  constructor: ->
    @handlers = []
  
  send: (message) ->
    process.nextTick => @fire message
  
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