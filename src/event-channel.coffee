{include,Attributes,toError,merge} = require "fairmont"
Channel = require "./channel"
PatternSet = require "./pattern-set"

class EventChannel extends Channel
  
  include @, Attributes
  
  constructor: ->
    super
    @channels = {}
    @_patterns = new PatternSet
    @receive (message) => 
      @_patterns.match message.event, (event) =>
        @channels[event]?.fire message

  on: (event, handler) ->
    @_patterns.add event
    @channels[event] ?= new Channel
    @channels[event].receive handler

  once: (event, handler) ->
    _handler = =>
      handler()
      @remove event, _handler
    on event, _handler
        
  remove: (event, handler) ->
    @channels[event]?.remove handler

  forward: (channel) ->
    if @name?
      @receive (message) =>
        channel.fire (merge message,
            event: "#{@name}.#{message.event}")
    else
      super

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
      @send event: "error", (toError error)

module.exports = EventChannel
  