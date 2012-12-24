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
        publish.once "*", => @clients.release client
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
          client.unsubscribe => @clients.release client
  
  _acquire: (handler) ->
    @events.source "acquire", (acquire) =>
      @clients.acquire acquire.callback
      acquire.on "success", (message) => handler message.content
       
  _release: (client) -> @clients.release client
    
  end: -> @clients.drain => @clients.destroyAllNow()
  
module.exports = RedisTransport