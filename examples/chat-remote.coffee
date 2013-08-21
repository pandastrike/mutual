http = require "http"
{RemoteChannel,EventChannel,RedisTransport} = require "../src/index"
transport = new RedisTransport host: "localhost", port: 6379
events = new EventChannel

# all error events will bubble-up here
events.on "error", (error) -> console.log error

{getChannel,makeChannel} = do (channels = {}) ->
  makeChannel: (name) -> 
    channel = new RemoteChannel {name,transport}
    channel.forward(events, name)
    channel.listen()
    channel
  getChannel: (name) -> channels[name] ?= makeChannel(name)

express = require "express"
app = express()

app.use (request, response, next) -> 
  body = ""
  request.on "data", (data) -> body += data
  request.on "end", ->
    request.body = body
    next()

app.get '/:channel', (request, response) ->
  {channel} = request.params
  getChannel(channel).once "message", (message) ->
    response.send message

app.post '/:channel', (request, response) ->
  response.send 202, ""
  {channel} = request.params
  message = request.body
  getChannel(channel).emit "message", message
  
http.createServer(app).listen(1337)