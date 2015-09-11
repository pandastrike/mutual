EventChannel = require "../src/event-channel"
DurableChannel = require "../src/durable-channel"
RedisTransport = require "../src/redis-transport"
helpers = require "./helpers"
{testify, assert, events} = helpers
{randomKey} = require "key-forge"

redisOptions = {host: "127.0.0.1", port: 6379}

testify.test "A durable channel", (context) ->

  context.test "can send and reply to durable messages", (context) ->

    dispatcher = new DurableChannel({name: "dispatcher-1", redis: redisOptions})
    worker = new DurableChannel({name: "worker-1", redis: redisOptions})

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

    dispatcher = new DurableChannel({name: "dispatcher-2", redis: redisOptions})
    worker = new DurableChannel({name: "worker-2", redis: redisOptions})

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


  context.test "replying to a timed out message", (context) ->

    dispatcher = new DurableChannel({name: "dispatcher-3", redis: redisOptions})
    worker = new DurableChannel({name: "worker-3", redis: redisOptions})

    context.test "sending message", ->
      dispatcher.on "ready", ->
        dispatcher.send {content: "task", to: "worker-3", timeout: 3000}

    context.test "receiving message", (context) ->
      worker.on "ready", ->
        worker.listen().on "success", ->
          worker.once "message" , (message) ->
            dispatcher.on "timeout", ->
              worker.reply {message, response: "reply"}
              setTimeout ->
                  worker.end()
                  dispatcher.end()
                  context.pass()
                , 500


  context.test "worker receives a timed out message", (context) ->

    dispatcher = new DurableChannel({name: "dispatcher-4", redis: redisOptions})
    worker = new DurableChannel({name: "worker-4", redis: redisOptions})

    context.test "sending message", ->
      dispatcher.on "ready", ->
        dispatcher.send {content: "task", to: "worker-4", timeout: 100}

    context.test "receiving message", (context) ->
      worker.on "ready", ->
        worker.listen().on "success", ->
          timeoutListener = ->
            worker.once "message", (message) ->
              context.fail("worker received a timed out message")
            setTimeout -> 
                worker.end()
                dispatcher.end()
                context.pass()
              , 100
          setTimeout(timeoutListener, 3000)


  context.test "dispatcher sends 1K messages in quick succession", (context) ->
    messageCount = 1000
    replies = 0
    timeouts = 0
    redisOptions.poolSize = 1000

    transport = new RedisTransport redisOptions
    worker = new DurableChannel({name: "worker-5", redis: redisOptions})
    dispatchers = []

    context.test "sending 1K messages", (context) ->
      endWhenDone = ->
        if messageCount == timeouts + replies
          setTimeout ->
            transport.end()
            worker.end()
            for dispatcher in dispatchers
              dispatcher.end()
            if messageCount < timeouts + replies
              context.fail()
            else
              context.pass()
          , 10000

      for i in [1..messageCount]
        do ->
          dispatcher = new DurableChannel({name: "dispatcher-5-#{randomKey(16)}", redis: redisOptions, transport: transport})
          dispatchers.push(dispatcher)
          dispatcher.listen().on "success", ->
            dispatcher.on "timeout", (message) ->
              timeouts++
              endWhenDone()
            dispatcher.on "message", (message) ->
              dispatcher.close(message).on "success", ->
                replies++
                endWhenDone()
          dispatcher.send {content: i, to: "worker-5", timeout: 2000}

    context.test "receiving 1K messages", ->
      worker.on "ready", ->
        worker.listen().on "success", ->
          worker.on "message", (message) ->
            worker.reply {message, response: message.content}
