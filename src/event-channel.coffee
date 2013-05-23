{include,Attributes,merge,type,w} = require "fairmont"
Channel = require "./channel"
PatternSet = require "./pattern-set"

# TODO: This is temporarily here until I can properly extract it

class Signature 
  
  constructor: -> 
    @signatures = {}
    @failHandler = => false
  
  on: (types,processor) ->
    @signatures[types.join "."] = processor
    @
  
  fail: (handler) =>
    @failHandler = handler
    @

  match: (args) -> 
    types = (type arg for arg in args)
    signature = types.join "."
    processor = @signatures[signature]
    if processor?
      processor
    else
      console.log signature
      console.log @signatures
      @failHandler
    
overload = (declarations) ->
  signature = (declarations new Signature)
  (args...) ->
    ((signature.match args) args...)

# $.Overloading = 
#   overload: (name,declarations) ->
#     @::[name] = $.overload declarations
#     @

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
    _handler = (args...)=>
      handler(args...)
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
    
    # TODO: is there a cleaner way to do this without memoizing like this?
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
      signature.fail ->
        throw new TypeError "EventChannel::source, invalid argument(s)"
    
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
      
  serially: (builder) ->
    functions = []
    go = (fn) -> (functions.push fn)
    builder go
    events = @source()
    (arg) ->
      _fn = (arg) ->
        fn = functions.shift()
        if fn?
          try
            rval = fn(arg)
            if rval?.on?
              rval.on "success", _fn
              rval.on "error", (error) ->
                events.emit "error", error
            else
              _fn rval
          catch error
            events.emit "error", error
        else
          events.emit "success", arg
      _fn( arg )
      return events

  concurrently: (builder) ->
    functions = []
    go = (name,fn) ->
      functions.push (if fn? then [name,fn] else [null,name])
    builder go
    events = @source()
    (arg) ->
      _fn = (arg) ->
        results = {}; errors = 0
        called = 0; returned = 0
        finish = ->
          returned++
          if called == returned
            if errors is 0
              events.emit "success", results
            else
              events.emit "error", 
                new Error "concurrently: unable to complete"
        error = (_error) ->
          errors++
          finish()
        return arg if functions.length is 0
        for [name,fn] in functions
          do (name,fn) ->
            success = (result) ->
              results[name] = result if name?
              finish()
            try
              called++
              rval = fn( arg )
              if rval?.on?
                rval.on "success", success 
                rval.on "error", error
              else
                success rval
            catch _error
              error _error
      _fn( arg )
      events

  sleep: (ms) ->
    @source (events) ->
      setTimeout (-> events.emit "success"), ms

module.exports = EventChannel
  