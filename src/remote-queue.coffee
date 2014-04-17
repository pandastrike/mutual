RemoteChannel = require "./remote-channel"

class RemoteQueue extends RemoteChannel
  
  send: (message) ->
    @events.source (events) =>
      _events = @transport.enqueue (@package message)
      _events.forward events

  listen: ->
    @events.source (events) =>
      unless @isListening
        @isListening = true
        
        _dequeue = =>
          @transport.dequeue(@name).on "success", (message) =>
            @fire message
            if @channels[message.event]?.handlers?.length > 0
              setImmediate(_dequeue)

        @superOn ?= @on
        @on = (event, handler) =>
          unless event in ["success", "error", "ready"]
            @superOn(event, handler)
            _dequeue()

        events.emit "success"

module.exports = RemoteQueue
  
