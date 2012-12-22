{type} = require "fairmont"

class Channel
  
  constructor: (@name) ->
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
    
  source: (args...) ->
    [name,block] = switch args.length
      when 0 then [null,null]
      when 1 
        switch (type args[0])
          when "string" then [args[0],null]
          when "function" then [null,args[0]]
      else args
    
    channel = new @constructor name
    channel.forward @, @name
    (block channel) if block?
    channel    
    
  package: (message) ->
    message
    
module.exports = Channel