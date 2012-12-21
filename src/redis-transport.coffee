redis = require "redis"
{Pool} = require "generic-pool"
{type,toError} = require "fairmont"

EventChannel = require "event-channel"

class RedisTransport extends EventChannel
 
  constructor: (options) ->
    {@events,@name} = options
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
  
  send: (message) ->
    @events.source "publish", (publishEvents) =>
      {channel,id} = message
      @_acquire (client) =>
        ch.once "*", => @clients.release client
        client.publish channel, JSON.stringify(message), publishEvents.callback

  run: -> 
    @run = => # no-op / idempotent
    @_acquire (client) =>
      client.subscribe @name
      client.on "message", (channel,json) =>
        ch.safely =>
          message = JSON.parse json
          @fire message
          @stop = =>
            client.unsubscribe => @clients.release client
            @stop = => # no-op / idempotent
  
  stop: => # no-op until you've run something
    
  
  _acquire: (handler) ->
    @bus.channel "client", (ch) =>
      @clients.acquire ch.callback
      ch.on "success", handler
       
  _release: (client) -> @clients.release client
    
  end: -> @clients.drain => @clients.destroyAllNow()
  
module.exports = Transport