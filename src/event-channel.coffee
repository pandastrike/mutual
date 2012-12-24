{include,Attributes,Catalog,toError,throwError,merge,overload} = require "fairmont"
Channel = require "./channel"
PatternSet = require "./pattern-set"

Catalog.add
  "invalid-argument": (fname) -> "#{fname}: Invalid argument"
  
class EventChannel extends Channel
  
  include @, Attributes
  
  constructor: ->
    super
    @channels = {}
    @_patterns = new PatternSet
    @receive (message) => 
      @_patterns.match message.event, (event) =>
        @channels[event]?.fire message

  fire: (args...) ->
    
    @fire = overload (signature) =>
      signature.on ["string"], (event) =>
        super event: event
      signature.on ["string", "object"], (event,message) =>
        message.event = event
        super message
      signature.on ["object"], (message) =>
        super message
      signature.fail =>
        throwError "invalid-argument", "EventChannel::fire"
    
    @fire args...

  on: (event, handler) ->
    @_patterns.add event
    @channels[event] ?= new Channel
    @channels[event].receive handler

  once: (event, handler) ->
    _handler = =>
      handler()
      @remove event, _handler
    @on event, _handler

  forward: (channel,name) ->
    @receive (message) =>
      if name?
        message = merge message, event: "#{name}.#{message.event}"
      channel.fire message
      
  source: (args...) ->

    _source = (name,block) =>
      channel = new @constructor
      channel.forward @, name
      block channel if block?
      channel
      
    @source = overload (signature) =>
      signature.on [], => super
      signature.on ["function"], (block) => super
      signature.on ["string"], _source
      signature.on ["string","function"], _source
    
    @source args...

  remove: (event, handler) ->
    @channels[event]?.remove handler

  @reader "callback", ->
    # memoize the getter ...
    @callback = (error,results) =>
      unless error?
        @send event: "success", content: results
      else
        @send event: "failure", content: error
    
  emitter: (emitter) -> 
    self = @
    emit = emitter.emit
    emitter.emit = (event, args...) ->
      emit.call @, event, args...
      # normalize the args for packaging into
      # a message object
      args = switch args.length
        when 0 then null
        when 1 then args[0]
        else args
      self.send event: event, content: args
    emitter

  safely: (fn) ->
    try
      fn()
    catch error
      @send event: "error", content: (toError error)

module.exports = EventChannel
  