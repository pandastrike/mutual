EventChannel = require "../src/event-channel"

channel = new EventChannel

channel.send event: "greeting", content: "hello"

# we can set this after we send the message, 
# because ::send doesn't do anything until nextTick
channel.on "greeting", (message) =>
  console.log message.content

{readFile} = require "fs"

channel = new EventChannel

readFile __filename, "utf-8", channel.callback
readFile __filename+"x", "utf-8", channel.callback

channel.on "success", (message) =>
  console.log message.content

channel.on "failure", (message) =>
  console.log message.content