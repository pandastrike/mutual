EventChannel = require "../src/event-channel"
helpers = require "./helpers"
{testify, assert} = helpers

testify.test "An event channel", (context) ->

  context.test "can send and receive events", (context) ->

    channel = new EventChannel

    channel.emit "hello", "Dan"

    channel.on hello: (message) =>
      context.test "using an 'on' handler", ->
        assert.ok message is "Dan"
        
  context.test "wrapping Node.js typical callbacks", (context) ->
    node_style = (arg, callback) ->
      if arg == true
        callback null, "a result"
      else
        callback new Error "Ha! Wrong."

    base_channel = new EventChannel
    wrapped = base_channel.wrap node_style

    context.test "returns a function", ->
      assert.equal typeof(wrapped), "function"

    context.test "invoking the wrapper function", (context) ->
      channel = wrapped(true)
      context.test "returns an EventChannel", ->
        assert.equal channel.constructor, EventChannel

    context.test "the wrapper channel emits 'success' for results", (context) ->
      channel = wrapped(true)
      channel.on "success", (result) ->
        context.test "and provides the result to the handler", ->
          assert.equal result, "a result"

    context.test "the wrapper channel emits 'error' for errors", (context) ->
      channel = wrapped(false)
      channel.on "error", (error) ->
        context.test "and provides the error to the handler", ->
          assert.equal error.message, "Ha! Wrong."

    context.test "when an argument is itself an EventChannel", (context) ->
      other_function = (callback) ->
        callback null, true

      other_wrapped = base_channel.wrap(other_function)

      channel = wrapped(other_wrapped())

      channel.on "success", (result) ->
        context.test "it is asynchronously evaluated", ->
          assert.equal result, "a result"



  context.test ".concurrently", (context) ->
    source = new EventChannel
    
    context.test "defines functions which return EventChannels", (context) ->

      context.test "emits 'success' when all succeed", (context) ->
        channel = do source.concurrently (action) ->
          action "foo", -> "I am foo"
          action "bar", -> "I am bar"

        channel.on "error", (error) ->
          context.fail(error)

        channel.on "success", (results) ->
          context.test "with the results collected by name", ->
            assert.deepEqual results, {foo: "I am foo", bar: "I am bar"}

      context.test "emits 'error' when any fail", (context) ->
        channel = do source.concurrently (action) ->
          action "foo", -> throw new Error "error foo"
          action "bar", -> throw new Error "error bar"

        channel.on "success", (results) ->
          context.fail("Should not succeed")

        channel.on "error", (error) ->
          context.test "with the errors collected by name", ->
            assert.ok error.errors.foo instanceof Error
            assert.ok error.errors.bar instanceof Error





  context.test "can wrap Node-style callback functions", (context) ->
    
    channel = new EventChannel
    channel.on error: (error) ->
      console.log error
        
    fs = require "fs"
    [read, write] = channel.wrap(fs.readFile, fs.writeFile)
    saved = {}
    do channel.serially (go) ->
      go -> read("test/data/foo.txt", encoding: "utf8")
      go (text) ->
        saved.text = text
        write("test/data/bar.txt", text, encoding: "utf8")
      go -> read("test/data/bar.txt", encoding: "utf8")
      go (text) ->
        context.test "for use with ::serially", ->
          assert.ok saved.text == text
