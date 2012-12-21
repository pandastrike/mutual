redis = require "redis"
{Pool} = require "generic-pool"
{type,toError} = require "fairmont"

EventChannel = require "event-channel"

class RedisTransport 
  
  constructor: (options) ->
    @events = options.events.source "redis-transport"
    poolEvents = @events.source "pool"
    @clients = Pool 
      name: "redis-transport", max: 10
      create: (callback) => 
        {port, host, options} = options
        client = redis.createClient port, host, options
        client.on "error", (error) -> callback error
        client.on "connect", -> callback null, client
      destroy: (client) => client.quit()
      log: (string,level) => poolEvents.fire event: level, content: string
  
  publish: (message) ->
    @events.source "publish", (publishEvents) =>
      {channel,id} = message
      @_acquire (client) =>
        publishEvents.once "*", => @clients.release client
        client.publish channel, JSON.stringify(message), publishEvents.callback

  subscribe: (name) ->
    @events.source "subscribe", (subscribeEvents) =>
      @_acquire (client) =>
        client.subscribe name
        client.on "message", (channel,json) =>
          subscribeEvents.safely =>
            message = JSON.parse json
            subscribeEvents.@fire event: message, content: message
        subscribeEvents.on "unsubscribe", =>
          client.unsubscribe => @clients.release client
  
  _acquire: (handler) ->
    @bus.channel "client", (ch) =>
      @clients.acquire ch.callback
      ch.on "success", handler
       
  _release: (client) -> @clients.release client
    
  end: -> @clients.drain => @clients.destroyAllNow()
  
module.exports = Transport