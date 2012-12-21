Channel = require "../src/channel"

channel = new Channel

channel.send content: "hello"

# we can set this after we send the message, 
# because ::send doesn't do anything until nextTick
channel.receive (message) =>
  console.log message.content