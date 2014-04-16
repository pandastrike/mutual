EventChannel = require "../src/event-channel"
DurableChannel = require "../src/durable-channel"
helpers = require "./helpers"
{testify, assert, events} = helpers

testify.test "A durable channel", (context) ->

  context.test "can send and reply to durable messages", (context) ->

    dispatcher = new DurableChannel({name: "dispatcher-1", redis: {host: "127.0.0.1", port: 6379}})
    worker = new DurableChannel({name: "worker-1", redis: {host: "127.0.0.1", port: 6379}})

    context.test "sending message", ->
      dispatcher.on "ready", ->
        dispatcher.send {content: "task", to: "worker-1"}

    context.test "receiving message", (context) ->
      worker.on "ready", ->
        worker.listen().on "success", ->
          worker.on "message", (message) ->
            assert.ok (message.content is "task")
            worker.reply {message, response: "reply", timeout: 5000}
            context.pass()

    context.test "receiving reply", (context) ->
      dispatcher.listen().on "success", ->
        dispatcher.on "message", (message) ->
            assert.ok (message.content is "reply")
            dispatcher.close(message).on "success", ->
              worker.end()
              dispatcher.end()
              context.pass()


  context.test "can set timeout on message", (context) ->

    dispatcher = new DurableChannel({name: "dispatcher-2", redis: {host: "127.0.0.1", port: 6379}})
    worker = new DurableChannel({name: "worker-2", redis: {host: "127.0.0.1", port: 6379}})

    context.test "sending message", ->
      dispatcher.on "ready", ->
        dispatcher.send {content: "task", to: "worker-2", timeout: 1000}

    context.test "receiving message", (context) ->
        worker.on "ready", ->
        worker.listen().on "success", ->
          worker.once "message", (message) ->
            assert.ok (message.content is "task")
            context.pass()

    context.test "waiting for timeout", (context) ->
      dispatcher.once "timeout", ->
        worker.end()
        dispatcher.end()
        context.pass()