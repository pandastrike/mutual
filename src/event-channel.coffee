{include, Attributes, merge, type, w} = require "fairmont"
Channel = require "./channel"
PatternSet = require "./pattern-set"
{overload} = require "typely"
{EventEmitter} = require "events"

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
    go = (fn) ->
      functions.push fn
    builder go
    events = @source()
    (arg) ->
      results = []
      count = 0
      _fn = (arg) ->
        results.push arg unless arg == undefined
        fn = functions.shift()
        if fn?
          count++
          try
            rval = fn(arg)
            if (rval instanceof EventChannel) || (rval instanceof EventEmitter)
              rval.on "success", _fn
              rval.on "error", (error) ->
                events.emit "error", error
            else
              _fn rval
          catch error
            events.emit "error", error
        else
          events.emit "success", results
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
        results = {}; errors = {}
        called = 0; returned = 0
        finish = ->
          returned++
          if called == returned
            if Object.keys(errors).length == 0
              events.emit "success", results
            else
              _error = new Error "concurrently: unable to complete"
              _error.errors = errors
              events.emit "error", _error
        record_error = (name, _error) ->
          if name
            errors[name] = _error
          else
            errors.unnamed_actions ||= []
            errors.unnamed_actions.push _error
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
              if (rval instanceof EventChannel) || (rval instanceof EventEmitter)
                rval.on "success", success
                rval.on "error", (error) ->
                  record_error name, error
              else
                success rval
            catch _error
              record_error name, _error
      _fn( arg )
      events

  wrap: (fns...) ->
    rval = for fn in fns
      # produce a function that returns an EventChannel
      (args...) =>
        @source (events) =>
          # use the type detection in ::serially to asynchronously
          # evaluate any arguments that are themselves EventChannels.
          series = do @serially (step) =>
            for arg, i in args
              do (arg) =>
                # If the argument is not an EventChannel, it is simply
                # added to the series results array.
                # If the argument is an EventChannel, ::serially will
                # wait for the result and add it to the results array.
                step => arg
          series.on "error", (error) =>
            events.emit "error", error
          series.on "success", (results) =>
            # The items in the results array are now the arguments passed
            # to the wrapper function, except the EventChannel results
            # have been asynchronously evaluated.
            try
              fn(results..., events.callback)
            catch error
              events.emit "error", error

    if rval.length < 2 then rval[0] else rval

  
  sleep: (ms) ->
    @source (events) ->
      setTimeout (-> events.emit "success"), ms

module.exports = EventChannel
  
