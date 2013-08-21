http = require "http"
{EventChannel} = require "../src/index"
events = new EventChannel

# all error events will bubble-up here
events.on "error", (error) -> console.log error

{getChannel,makeChannel} = do (channels = {}) ->
  makeChannel: (name) -> events.source name
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