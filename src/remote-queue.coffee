RemoteChannel = require "./remote-channel"

class RemoteQueue extends RemoteChannel
  
  # @property [Boolean] stopping
  stopping: false
      
  send: (message) ->
    @events.source (events) =>
      _events = @transport.enqueue (@package message)
      _events.forward events
  
  listen: ->
    @events.source (events) =>
      unless @isListening
        @isListening = true
        @end = => @stopping = true
        _dequeue = =>
          unless @stopping
            _events = @transport.dequeue @name
            _events.on "success", (message) =>
              @events.source 
              @fire message
              do @events.serially (go) =>
                go =>
                  @events.source (events) =>
                    if @channels[message.event]?.handlers?.length > 0
                      events.emit "success"
                    else
                      @superOn = @on if !@superOn?
                      @on = (args...) =>
                        @superOn.call(@, args...)
                        events.emit "success"
                go => setImmediate _dequeue
          else
            @transport.end()
            
        _dequeue()
        events.emit "success"
          
module.exports = RemoteQueue
  
