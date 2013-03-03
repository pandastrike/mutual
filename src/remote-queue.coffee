{toError,Catalog} = require "fairmont"

Catalog.add "name-required", ->
  "Remote channels cannot be anonymous"

RemoteChannel = require "./remote-channel"

class RemoteQueue extends RemoteChannel
  
  constructor: (options) ->
    super
    @stopping = false
    
  send: (message) ->
    @events.source "send", (send) =>
      publish = @transport.enqueue (@package message)
      publish.forward send
  
  listen: ->
    @events.source "listen", (listen) =>
      unless @isListening
        @isListening = true
        @end = =>
          @stopping = true
          @transport.end()
        _dequeue = =>
          unless @stopping
            dequeue = @transport.dequeue @name
            dequeue.on "success", (message) ->
              listen.send message
              process.nextTick _dequeue
        _dequeue()
        listen.send "success"
  

module.exports = RemoteQueue
  
