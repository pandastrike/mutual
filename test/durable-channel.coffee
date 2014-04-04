{Redis} = require "pirate"
Transport = require "../src/redis-transport"
EventChannel = require "../src/event-channel"
DurableChannel = require "../src/durable-channel"
helpers = require "./helpers"
{testify, assert, events} = helpers

make = (name)->
  
  transport = new Transport
    host: "127.0.0.1"
    port: 6379

  transport.events.forward events

  adapter = new Redis.Adapter
    events: new EventChannel
    port: 6379
    host: "127.0.0.1"

  new DurableChannel({name, transport, adapter})

testify.test "A durable channel", (context) ->

  context.test "can send and reply to durable messages", (context) ->

    dispatcher = make("dispatcher")
    worker = make("worker")

    context.test "sending message", ->

      dispatcher.send {content: "task", to: "worker", timeout: 5000}

      context.test "receiving message", (context) ->
        workerListener = worker.listen()
        workerListener.on "ready", ->
          workerListener.on "message", (message) ->
            assert.ok (message.content is "task")
            worker.reply {message, response: "reply"}
            context.pass()

      context.test "receiving reply", (context) ->
        dispatcherListener = dispatcher.listen()
        dispatcherListener.on "ready", ->
          dispatcherListener.on "message", (message) ->
              assert.ok (message.content is "reply")
              dispatcher.close(message).on "success", ->
                worker.end()
                dispatcher.end()
                context.pass()


  context.test "can set timeout on message", (context) ->

    dispatcher = make("dispatcher")
    worker = make("worker")

    timeoutCheck = null

    context.test "sending message", (context) ->

      workerListener = worker.listen()
      workerListener.on "ready", ->
        workerListener.on "message", (message) ->
          assert.ok (message.content is "task")

      dispatcher.send {content: "task", to: "worker", timeout: 1000}, ->
        context.test "message timedout", ->
          clearTimeout(timeoutCheck)
          worker.end()
          dispatcher.end()
          context.pass()