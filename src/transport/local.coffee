{promise, resolve} = require "when"
{empty} = require "fairmont"

class _Channel

  constructor: ->
    @inbox = []

  send: (message) ->
    if @promise?
      @resolve message
      @promise = undefined
    else
      @inbox.push message

  receive: ->
    unless empty @inbox
      @inbox.shift()
    else
      @promise ?= promise (@resolve) =>

class Local

    @channels = {}

    send: (channel, message) ->
      (Local.channels[channel] ?= new _Channel).send message

    receive: (channel) ->
      (Local.channels[channel] ?= new _Channel).receive()

    close: -> resolve()

    @create: -> new Local

module.exports = Local
