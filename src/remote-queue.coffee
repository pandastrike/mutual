RemoteChannel = require "./remote-channel"

class RemoteQueue extends RemoteChannel
  
  # @property [Boolean] stopping
  stopping: false
  paused: true

  send: (message) ->
    @events.source (events) =>
      _events = @transport.enqueue (@package message)
      _events.forward events

  listen: ->
    @events.source (events) =>
      unless @isListening
        @isListening = true
        
        _resume = =>
          @paused = false
          @end = => @stopping = true
          setImmediate(_dequeue)

        _pause = =>
          @paused = true
          @end = => @transport.end()

        _dequeue = =>
          unless @stopping
            @transport.dequeue(@name).on "success", (message) =>
              @fire message
              if @channels[message.event]?.handlers?.length > 0
                _resume()
              else
                _pause()
          else
            @transport.end()

        @superOn ?= @on
        @on = (event, handler) =>
          unless event in ["success", "error", "ready"]
            @superOn(event, handler)
            _resume()

        _pause()
        events.emit "success"

module.exports = RemoteQueue
  
