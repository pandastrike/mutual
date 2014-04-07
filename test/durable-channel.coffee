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

    dispatcher = make("dispatcher-1")
    worker = make("worker-1")

    context.test "sending message", ->
      dispatcher.send {content: "task", to: "worker-1"}

    context.test "receiving message", (context) ->
      worker.on "ready", ->
        worker.on "message", (message) ->
          assert.ok (message.content is "task")
          worker.reply {message, response: "reply"}
          context.pass()

    context.test "receiving reply", (context) ->
      dispatcher.on "ready", ->
        dispatcher.on "message", (message) ->
            assert.ok (message.content is "reply")
            dispatcher.close(message).on "success", ->
              worker.end()
              dispatcher.end()
              context.pass()


  context.test "can set timeout on message", (context) ->

    dispatcher = make("dispatcher-2")
    worker = make("worker-2")

    context.test "sending message", ->
      dispatcher.send {content: "task", to: "worker-2", timeout: 1000}

    context.test "receiving message", (context) ->
      worker.on "ready", ->
        worker.on "message", (message) ->
          assert.ok (message.content is "task")
          context.pass()

    context.test "waiting for timeout", (context) ->
      dispatcher.on "ready", ->
        dispatcher.on "timeout", ->
          worker.end()
          dispatcher.end()
          context.pass()