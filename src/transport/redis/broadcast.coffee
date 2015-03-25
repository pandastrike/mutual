Evie = require "evie"
{async, stream} = require "fairmont"

Transport = require "./transport"

class Broadcast extends Transport

  constructor: ->
    super
    @streams = {}
    @subscriptions = []

  send: (channel, message) ->
    @acquire async (client, release) ->
      result = yield client.publish channel, message
      client.quit() # you can't reuse pub-sub clients
      result

  receive: async (channel) ->
    @streams[channel] ?=
      yield @acquire (client) =>
        events = Evie.create()
        client.subscribe channel
        @subscriptions.push client
        client.on "message", (channel, message) ->
          events.emit "data", message
        client.on "unsubscribe", ->
          events.emit "end"
          client.quit()  # you can't reuse pub-sub clients
          @streams[channel] = undefined
        stream events

    # TODO: Why isn't this returning a Promise
    # TODO: close needs to call unsubscribe...
    @streams[channel]()

  close: ->
    super
    client.unsubscribe() for client in @subscriptions

  @create: (args...) -> new Broadcast args...

module.exports = Broadcast
