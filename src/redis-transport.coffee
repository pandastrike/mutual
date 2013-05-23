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
    @events.source (events) =>
      {channel} = message
      @_acquire (client) =>
        events.once "*", => 
          # You can't reuse pub/sub clients
          @clients.destroy client
        client.publish channel, (JSON.stringify message), events.callback

  subscribe: (name) ->
    @events.source (events) =>
      @_acquire (client) =>
        client.subscribe name, ->
          events.fire event: "success"
        client.on "message", (channel,json) =>
          events.safely =>
            events.fire event: "message", content: (JSON.parse json)
        events.on "unsubscribe", =>
          client.unsubscribe => 
            # You can't reuse pub/sub clients
            @clients.destroy client
  
  enqueue: (message) ->
    @events.source (events) =>
      {channel} = message
      @_acquire (client) =>
        events.on "*", => @_release client
        client.lpush channel, JSON.stringify(message), events.callback
    
    
  dequeue: (name) ->
    @events.source (events) =>
      @_acquire (client) =>
        @events.source (_events) =>
          _events.on "*", => @_release client
          name = if (type name) is "array" then name else [ name ]
          client.brpop name..., 0, _events.callback
          _events.on "success", (results) =>
            events.safely =>
              [key, json] = results
              message = JSON.parse(json)
              events.emit "success", message
      
  _acquire: (handler) ->
    @events.source (events) =>
      @clients.acquire events.callback
      events.on "success", (client) => handler client
       
  _release: (client) -> @clients.release client
    
  end: -> @clients.drain => @clients.destroyAllNow()
  
module.exports = RedisTransport