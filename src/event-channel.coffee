{include, Attributes, Catalog, toError, throwError, merge, overload, w} = require "fairmont"
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
        @channels[event]?.fire message.content

  on: (event, handler) ->
    @_patterns.add event
    @channels[event] ?= new Channel
    @channels[event].receive handler

  once: (event, handler) ->
    _handler = =>
      handler()
      @remove event, _handler
    @on event, _handler

  emit: (event, content) ->
    @send event: event, content: content
    
  forward: (channel, name) ->
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

  # The use of the => is intentional here:
  # we want to use callback as a stand-alone
  # property, not a method
  callback: (error, results) =>
    unless error?
      @emit "success", results
    else
      @emit "error", error
    
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
      self.emit event, args
    emitter

  safely: (fn) ->
    try
      fn()
    catch error
      @emit "error", error

module.exports = EventChannel
  