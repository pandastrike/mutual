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
    process.on "exit", => @close

  acquire: async (f) ->
    client = if empty @pool
      yield create_client @options
    else
      @pool.shift()
    release = (client) => @pool.push client
    f client, release

  send: (channel, message) ->
    @acquire async (client, release) ->
      result = yield client.lpush channel, JSON.stringify message
      release client
      result

  receive: (channel) ->
    {timeout} = @options
    @acquire async (client, release) ->
      (result = yield client.brpop channel, timeout) until result
      release client
      JSON.parse second result

  close: async ->
    yield sleep @options.timeout * 1000
    client.quit() for client in @pool

  @create: (args... ) -> new Transport

module.exports = Transport
