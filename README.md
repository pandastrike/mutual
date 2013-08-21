# Mutual

Mutual is inspired by Scala's Actor model. Concurrency is managed by setting up Channels between participants. Remote channels are implemented by using Redis as a transport. Event channels provide an `EventEmitter` like interface. Builder methods, in combination with event-bubbling, can be used to build complex chains of asynchronous processing.

    fs = require "fs"
    
    {EventChannel} = require "mutual"
    events = new EventChannel
    
    # all error events will bubble-up here
    events.on "error", (error) -> console.log error
    
    # wrap a Node-style callback function
    read = events.wrap(fs.readFile)
    
    # use builder function to create an asynchronous control flow
    do events.serially (go) ->
      go -> read("foo.txt", encoding: "utf8")
      go (text) -> console.log text
      
Remote channels are just event channels, which means you can swap them out without changing any code. Here's a simple express app that implements a chat interface:

    http = require "http"
    {EventChannel} = require "mutual"
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
    
If you run this, you can do a GET to a channel URL (ex: `/foo`) and then POST a message to it.

        curl http://localhost:1337/foo &
        curl http://localhost:1337/foo -d "Hello"

The original GET will return the message.

Of course, this isn't much different from what we could do using `EventEmitter`, outside of utilizing the event bubbling for `error` events. However, this version also has a big limitation: it only works for one process. If we start to get lots of messages, we'll want to be able to run multiple processes, perhaps even across multiple machines.

With Mutual, all we need to do, basically, is change `makeChannel` so that it returns a `RemoteChannel`. 

First, let's `require` the `RedisTransport` and `RemoteChannel`:

    {RemoteChannel,EventChannel,RedisTransport} = require "../src/index"

Next, well instantiate the transport:

    transport = new RedisTransport host: "localhost", port: 6379
    
Finally, we just change our `makeChannel` function:

    makeChannel: (name) -> 
      channel = new RemoteChannel {name,transport}
      channel.forward(events, name)
      channel.listen()
      channel

The rest of our code remains the same. We've just moved to an implementation that will work across multiple process or machine boundaries by adding and modifying a few lines of code. The bulk of our application is unchanged.

Our final version of our little chat API can be found [in the examples][ex].

[ex]:https://github.com/dyoder/mutual/tree/master/examples

## Installation

    npm install mutual
    
## Status

In development - the interface is relatively stable, but we haven't done a lot of load and performance testing.
