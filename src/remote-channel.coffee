{toError,Catalog} = require "fairmont"

Catalog.add "name-required", ->
  "Remote channels cannot be anonymous"

EventChannel = require "./event-channel"

class RemoteChannel extends EventChannel
  
  constructor: (options) ->
    {@name,@transport,@events} = options
    throw (toError "name-required") unless @name?
    @events ?= new EventChannel @name
    
  package: (message) ->
    message.channel = @name
    
  # Override ::send to mean 'send this message across the network'
  # No receive handlers will fire unless ::run is invoked
  send: (message) ->
    @events.source "send", (send) =>
      publish = @transport.publish (@package message)
      publish.foward send
  
  # Run means 'listen for messages on the network'
  listen: ->
    @events.source "listen", (listen) =>
      subscribe = @transport.subscribe @name
      subscribe.on "message", (message) => @fire message.content
      @end = =>
        subscribe.fire event: "unsubscribe"
    
module.exports = RemoteChannel
  
  