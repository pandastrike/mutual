{async, is_array, second} = require "fairmont"

Transport = require "./transport"

class Queue extends Transport

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

  @create: (args...) -> new Queue args...

module.exports = Queue
