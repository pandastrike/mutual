{toError,Catalog} = require "fairmont"

Catalog.add "name-required", ->
  "Remote channels cannot be anonymous"

EventChannel = require "./event-channel"

class RemoteChannel extends EventChannel
  
  constructor: (options) ->
    {@name,@transport,events} = options
    throw (toError "name-required") unless @name?
    @events = if events?
      events.source @name
    else
      new EventChannel @name
    
  package: (message) ->
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
    subscribe = @transport.subscribe @name
    subscribe.forward @events
    @end = =>
      subscribe.fire event: "unsubscribe"
      @transport.end()
    
module.exports = RemoteChannel
  
  