setImmediate = process.nextTick unless setImmediate?

RemoteChannel = require "./remote-channel"

class RemoteQueue extends RemoteChannel
  
  constructor: (options) ->
    super
    @stopping = false
    
  send: (message) ->
    @events.source (events) =>
      _events = @transport.enqueue (@package message)
      _events.forward events
  
  listen: ->
    @events.source (events) =>
      unless @isListening
        @isListening = true
        @end = =>  @stopping = true
        _dequeue = =>
          unless @stopping
            _events = @transport.dequeue @name
            _events.on "success", (message) =>
              @fire message
              setImmediate _dequeue
          else
            @transport.end()
            
        _dequeue()
        events.emit "success"
          
module.exports = RemoteQueue
  
