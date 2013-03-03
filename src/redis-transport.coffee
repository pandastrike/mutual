redis = require "redis"
{Pool} = require "generic-pool"
{type,toError} = require "fairmont"
EventChannel = require "./event-channel"

class RedisTransport 
  
  constructor: (options) ->
    @events = new EventChannel
    poolEvents = @events.source "pool"
    @clients = Pool 
      name: "redis-transport", max: 10
      create: (callback) => 
        {port, host} = options
        client = redis.createClient port, host, options.redis
        client.on "error", (error) -> callback error
        client.on "connect", -> callback null, client
      destroy: (client) => client.quit()
      log: (string,level) => poolEvents.fire event: level, content: string
  
  publish: (message) ->
    @events.source "publish", (publish) =>
      {channel} = message
      @_acquire (client) =>
        publish.once "*", => 
          # You can't reuse pub/sub clients
          @clients.destroy client
        client.publish channel, (JSON.stringify message), publish.callback

  subscribe: (name) ->
    @events.source "subscribe", (subscribe) =>
      @_acquire (client) =>
        client.subscribe name, ->
          subscribe.fire event: "success"
        client.on "message", (channel,json) =>
          subscribe.safely =>
            subscribe.fire event: "message", content: (JSON.parse json)
        subscribe.on "unsubscribe", =>
          client.unsubscribe => 
            # You can't reuse pub/sub clients
            @clients.destroy client
  
  enqueue: (message) ->
    @events.source "enqueue", (enqueue) =>
      {channel} = message
      @_acquire (client) =>
        client.lpush channel, JSON.stringify(message), enqueue.callback
    
    
  dequeue: (name) ->
    @events.source "dequeue", (dequeue) =>
      @_acquire (client) =>
        dequeue.source "transport", (brpop) =>
          brpop.once "*", => @clients.release client
          name = if (type name) is "array" then name else [ name ]
          client.brpop name..., 0, brpop.callback
          brpop.on "success", (results) =>
            dequeue.safely =>
              [key,json] = results
              message = JSON.parse(json)
              dequeue.send "success", message
      
  _acquire: (handler) ->
    @events.source "acquire", (acquire) =>
      @clients.acquire acquire.callback
      acquire.on "success", (message) => handler message.content
       
  _release: (client) -> @clients.release client
    
  end: -> @clients.drain => @clients.destroyAllNow()
  
module.exports = RedisTransport