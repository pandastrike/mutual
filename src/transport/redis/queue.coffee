{promise} = require "when"
{lift} = require "when/node"
{sleep, call, async, merge, empty, is_array, second, remove} = require "fairmont"
redis = require "redis"

create_client = (options) ->
    {port, host, connection} = options
    _client = redis.createClient port, host, connection
    promise (resolve, reject) ->
      _client.on "error", (error) -> reject error
      _client.on "connect", ->
        # liftAll has weird side-effects
        _client.brpop = lift _client.brpop
        _client.lpush = lift _client.lpush
        _client.quit = lift _client.quit
        resolve _client

class Transport

  @defaults =
    timeout: 1
    port: 6379
    host: "localhost"
    connection: {}

  constructor: (options={}) ->
    @options = merge Transport.defaults, options
    @pool = []
    @closed = false
    process.on "exit", => @close

  acquire: async (f) ->

    client = if empty @pool
      yield create_client @options
    else
      @pool.shift()

    # if the transport is closed, just quit the client
    # otherwise return it to the pool
    release = (client) =>
      if @closed
        client.quit()
      else
        @pool.push client

    f client, release

  send: (channel, message) ->
    @acquire async (client, release) ->
      result = yield client.lpush channel, message
      release client
      result

  receive: (channel) ->
    {timeout} = @options
    @acquire async (client, release) ->
      result = yield client.brpop channel, timeout
      release client
      # strip the key name from the result
      if is_array result then second result else result

  close: ->
    @closed = true # all outstanding clients will close on their own
    @pool.shift().quit() until empty @pool

  @create: (args... ) -> new Transport

module.exports = Transport
