{is_string, is_object, is_function, first} = require "fairmont"

assert = (x) ->
  throw new TypeError unless x

map = (fn) ->
  (args...) ->
    if args.length == 1 && is_object first args
      [map] = args
      (fn.call @, event, x) for event, x of map
    else
      fn.call @, args...
    @

class Emitter

  constructor: (@transport, @name)->
    @handlers = {}

  emit: map (event, args...) ->
    assert is_string event
    handlers = (@handlers[event] ?= [])
    (handler args...) for handler in handlers
    unless event in ["_", "*"]
      @emit "_", args...
      @emit "*", args...

  on: map (event, handler) ->
    assert is_string event
    assert is_function handler
    handlers = (@handlers[event] ?= [])
    handlers.push handler

  once: map (event, handler) ->
    assert is_string event
    assert is_function handler
    _handler = (args...) =>
      handler args...
      @remove event, handler
    handlers = (@handlers[event] ?= [])
    handlers.push _handler

  remove: map (event, handler) ->
    assert is_string event
    assert is_function handler
    handlers = (@handlers[event] ?= [])
    @handlers[event] = (_h for _h in handlers when _h != handler)

  forward: map (event, emitter) ->
    assert is_string event
    assert emitter.emit?
    emit = (args...)-> emitter.emit event, args...
    @on event, emit

  @create: -> new Emitter


module.exports = Emitter
