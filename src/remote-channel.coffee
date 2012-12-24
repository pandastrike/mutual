{toError,Catalog} = require "fairmont"

Catalog.add "name-required", ->
  "Remote channels cannot be anonymous"

Channel = require "./channel"
EventChannel = require "./event-channel"

class RemoteChannel extends Channel
  
  constructor: (options) ->
    super
    {@name,@transport} = options
    throw (toError "name-required") unless @name?
    @events = new EventChannel
    
  package: (message) ->
    message = super
    message.channel = @name
    message
    
  # Override ::send to mean 'send this message across the network'
  # No receive handlers will fire unless ::run is invoked
  send: (message) ->
    @events.source "send", (send) =>
      publish = @transport.publish (@package message)
      publish.forward send
  
  # Run means 'listen for messages on the network'
  listen: ->
    @events.source "listen", (listen) =>
      subscribe = @transport.subscribe @name
      # TODO: Not sure I love this -- feels like we're overloading
      # the `subscribe` channel ... maybe a different message, ex: "ready"?
      subscribe.on "success", -> listen.fire "success"
      subscribe.on "message", (message) =>
        @fire message.content
      @end = =>
        subscribe.fire event: "unsubscribe"
        @transport.end()
    
module.exports = RemoteChannel
  
  