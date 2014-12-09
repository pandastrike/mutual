{testify, assert} = require "./helpers"
EventChannel = require "../src/event-channel"
Promisifier = require "../src/promisifier"

class Evented
  @events: new EventChannel

  constructor: (@x, @y) ->
  
  init: ->
    Evented.events.source (events) ->
      events.emit "ready", "ready"

  @classMethod: (a, b) ->
    Evented.events.source (events) ->
      events.emit "success", (a + b)

  @classMethodThatErrors: ->
    Evented.events.source (events) ->
      events.emit "error", "error"

  instanceMethod: ->
    Evented.events.source (events) =>
      events.emit "success", (@x + @y)

  instanceMethodThatErrors: ->
    Evented.events.source (events) ->
      events.emit "error", "error"

Evented = Promisifier.promisify Evented 

testify.test "Promisifier", (context) ->

  context.test "can promisify class methods", (context) ->
    Evented.classMethod(1, 2)
    .then (res) ->
      assert.ok res is 3
      context.pass()
    .catch (err) ->
      context.fail()

  context.test "can promisify class methods and catch rejections", (context) ->
    Evented.classMethodThatErrors()
    .then (res) ->
      context.fail()
    .catch (err) ->
      assert.ok err is "error"
      context.pass()

  context.test "can promisify instance methods", (context) ->
    evented = new Evented(3, 4)
    evented.instanceMethod()
    .then (res) ->
      assert.ok res is 7
      context.pass()
    .catch (err) ->
      context.fail()

  context.test "can promisify instance methods and catch rejections", (context) ->
    evented = new Evented
    evented.instanceMethodThatErrors()
    .then (res) ->
      context.fail()
    .catch (err) ->
      assert.ok err is "error"
      context.pass()

  context.test "can promisify methods that emit events other than success and error", (context) ->
    evented = new Evented
    evented.init()
    .then (res) ->
      assert.ok res is "ready"
      context.pass()
    .catch (err) ->
      context.fail()