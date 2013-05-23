getter = (fn) -> 
  get: -> fn()
  enumerable: true
  
Object.defineProperties module.exports,
  Channel: getter -> require "./channel"
  EventChannel: getter -> require "./event-channel"
  RemoteChannel: getter -> require "./remote-channel"
  RemoteQueue: getter -> require "./remote-queue"