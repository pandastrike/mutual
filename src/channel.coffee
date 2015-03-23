{promise, resolve} = require "when"
{async, is_string, is_object, is_function, empty, first} = require "fairmont"
Local = require "./transport/local"

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

class Channel

  constructor: (@name, @transport)->
    assert is_string @name
    @transport ?= Local.create()
    @handlers = {}
    @closed = @listening = false

  emit: map (event, args...) ->
    assert is_string event
    @transport.send @name, JSON.stringify [ event, args...]
    unless event in ["_", "*"]
      @emit "_", args...
      @emit "*", args...

  on: map (event, handler) ->
    assert is_string event
    assert is_function handler
    handlers = (@handlers[event] ?= [])
    handlers.push handler
    @listen()

  once: map (event, handler) ->
    assert is_string event
    assert is_function handler
    _handler = (args...) =>
      handler args...
      @remove event, handler
    handlers = (@handlers[event] ?= [])
    handlers.push _handler
    @listen()

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

  listen: async ->
    unless @listening
      @listening = true
      until @closed
        result = yield @transport.receive @name
        if result
          [event, args...] = JSON.parse result
          handlers = (@handlers[event] ?= [])
          (handler args...) for handler in handlers
      @listening = false

  close: ->
    @closed = true
    @transport.close()


  @create: (args...) -> new Channel args...


module.exports = Channel
