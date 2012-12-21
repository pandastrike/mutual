EventChannel = require "./event-channel"

class RemoteChannel extends EventChannel
  
  constructor: (@name,@transport) ->
    
  # Override ::send to mean 'send this message across the network'
  # No receive handlers will fire unless ::run is invoked
  send: (message) ->
  
  # Run means 'listen for messages on the network'
  run: ->
    
    
  
module.exports = RemoteChannel
  
  