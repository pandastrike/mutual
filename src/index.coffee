getter = (fn) -> 
  get: -> fn()
  enumerable: true
  
Object.defineProperties module.exports,
  Channel: getter -> require "./channel"
  EventChannel: getter -> require "./event-channel"
  RemoteChannel: getter -> require "./remote-channel"
  RedisTransport: getter -> require "./redis-transport"
  RemoteQueue: getter -> require "./remote-queue"
  DurableChannel: getter -> require "./durable-channel"