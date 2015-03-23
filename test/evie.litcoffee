    assert = require "assert"
    Amen = require "amen"
    Emitter = require "../src/evie.coffee"

    Amen.describe "Evie", (context) ->

      context.test "Simple event handler", ->
        done = false
        e = Emitter.create()

        e.on "message", (message) ->
          assert message == "Hello, World"
          done = true

        e.emit "message", "Hello, World"

        assert done

      context.test "Bad arguments", ->
        e = Emitter.create()
        assert.throws -> e.on "foo", 7
        assert.throws -> e.emit []

      context.test "Mapped event handler", ->
        done = false
        e = Emitter.create()

        e.on
          dummy: ->
          message: (message) ->
            assert message == "Hello, World"
            done = true

        e.emit message: "Hello, World"
        assert done

      context.test "Chained event handler", ->
        done = false
        e = Emitter.create()

        e.on
          dummy: ->
        .on
          message: (message) ->
            assert message == "Hello, World"
            done = true

        e.emit message: "Hello, World"
        assert done

      context.test "Wildcard event handler", ->
        done = false
        e = Emitter.create()

        e.on
          dummy: ->
        .on
          _: (message) ->
            assert message == "Hello, World"
            done = true

        e.emit message: "Hello, World"
        assert done
