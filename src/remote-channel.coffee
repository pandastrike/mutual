EventChannel = require "./event-channel"

class RemoteChannel extends EventChannel

  # @property [Boolean] isListening Is listening?
  isListening: false
  
  constructor: (options) ->
    super
    {@name,@transport} = options
    unless @name?
      throw new Error "Remote channels cannot be anonymous"
    @events = new EventChannel
    
  package: (message) ->
    message = super
    message.channel = @name
    message
    
  # Override ::send to mean 'send this message across the network'
  # ::fire now means to send locally only in addition to synchronously
  send: (message) ->
    @events.source (events) =>
      _events = @transport.publish (@package message)
      _events.forward events
  
  # Listen for messages on the network
  listen: ->
    @events.source (events) =>
      unless @isListening
        @isListening = true
        _events = @transport.subscribe @name
        # TODO: Not sure I love this -- feels like we're overloading
        # the `subscribe` channel ... maybe a different message, ex: "ready"?
        _events.on "success", -> events.fire event: "success"
        _events.on "message", (message) => @fire message
        @end = =>
          _events.fire event: "unsubscribe"
          @transport.end()
  
  end: ->
    @transport.end()

module.exports = RemoteChannel
  
  