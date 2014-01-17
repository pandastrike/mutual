{include, Attributes, merge, type, w} = require "fairmont"
Channel = require "./channel"
PatternSet = require "./pattern-set"
{overload} = require "typely"

class EventChannel extends Channel

  include @, Attributes
  
  constructor: ->
    super
    @channels = {}
    @_patterns = new PatternSet
    @receive (message) =>
      @_patterns.match message.event, (event) =>
        @channels[event]?.fire message.content

  on: overload (match, fail) ->

    match "string", "function", (name, handler) ->
      @_patterns.add name
      @channels[name] ?= new Channel
      @channels[name].receive handler
      @

    match "object", (handlers) ->
      @on( name, handler ) for name, handler of handlers
      @
    
    fail -> throw new TypeError "Invalid event handler specified"
    
  once: overload (match, fail) ->
  
    match "string", "function", (name, handler) ->
      _handler = (args...) =>
        handler(args...)
        @remove name, _handler
      @on name, _handler
      @

    match "object", (handlers) ->
      @once( name, handler ) for name, handler of handlers
      @

    fail -> throw new TypeError "Invalid event handler specified"


  emit: (name, content) ->
    @send event: name, content: content
    
  forward: (channel, name) ->
    @receive (message) =>
      if name?
        message = merge message, event: "#{name}.#{message.event}"
      channel.fire message
      
  source: ->
    
    # We redefine ::source on the fly like this so we can use
    # super with overload. See https://github.com/dyoder/typely/issues/1
    
    _source = (name, block) ->
      channel = new @constructor
      channel.forward @, name
      block channel if block?
      channel
    
    @source = overload (match, fail) ->
      match -> super
      match "function", (fn) -> super
      match "string", _source
      match "string", "function", _source
      fail -> throw new TypeError "Invalid event source specified"
      
    @source( arguments... )
    
  remove: (event, handler) ->
    @channels[event]?.remove handler

  # The use of the => is intentional here:
  # we want to use callback as a stand-alone
  # property, not a method
  callback: (error, results...) =>
    unless error?
      @emit "success", results...
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
            if rval instanceof EventChannel
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
    go = (name, fn) ->
      functions.push (if fn? then [name, fn] else [null, name])
    builder go
    events = @source()
    (arg) ->
      _fn = (arg) ->
        results = {}; errors = []
        called = 0; returned = 0
        finish = ->
          returned++
          if called == returned
            if errors.length == 0
              events.emit "success", results
            else
              _error = new Error "concurrently: unable to complete"
              _error.errors = errors
              events.emit "error", _error
        error = (_error) ->
          errors.push _error
          # TODO: If we're going to finish() here, why bother with an array
          # of errors ... ?
          finish()
        return arg if functions.length is 0
        for [name, fn] in functions
          do (name, fn) ->
            success = (result) ->
              results[name] = result if name?
              finish()
            try
              called++
              rval = fn( arg )
              if rval instanceof EventChannel
                rval.on "success", success
                rval.on "error", error
              else
                success rval
            catch _error
              error _error
      _fn( arg )
      events

  wrap: ->
    rval = for fn in arguments
      =>
        args = arguments
        @source (event) -> fn(args..., event.callback)
    if rval.length < 2 then rval[0] else rval
  
  sleep: (ms) ->
    @source (events) ->
      setTimeout (-> events.emit "success"), ms

module.exports = EventChannel
  
