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
        
  context.test "can wrap Node-style callback functions", (context) ->
    
    channel = new EventChannel
    channel.on error: (error) ->
      console.log error
        
    fs = require "fs"
    [read,write] = channel.wrap(fs.readFile,fs.writeFile)
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