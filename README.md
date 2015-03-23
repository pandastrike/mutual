# Mutual

Mutual wraps a messaging layer with a simple EventEmitter-style interface. Mutual uses Evie instead of EventEmitter, which allows for event-bubbling and a few other niceties.

To use Mutual, you simply create a `Channel` and subscribe to the events you're interested in.

```coffee
{Channel} = require "mutual"
channel = Channel.create "hello"

channel.on message: (message) ->
  assert message == "Hello, World"

channel.emit message: "Hello, World"
```

We can communicate remotely the same way just by adding a `Transport`.

**Client**
```coffee
{Channel, Transport} = require "mutual"
transport = Transport.Broadcast.Redis.create()
channel = Channel.create transport,  "hello"

channel.on message: (message) ->
  assert message == "Hello, World"
```

**Server**
```coffee
{Channel, Transport} = require "mutual"
transport = Transport.Broadcast.Redis.create()
channel = Channel.create transport,  "hello"

channel.emit message: "Hello, World"
```

The only code we had to change here was the creation of the channel. The code for using the channel remains the same.

Let's switch from a `Broadcast` channel to a `Queue` channel.

**Client**
```coffee
{Channel, Transport} = require "mutual"
transport = Transport.Queue.Redis.create()
channel = Channel.create transport,  "hello"

channel.on message: (message) ->
  assert message == "Hello, World"
```

**Server**
```coffee
{Channel, Transport} = require "mutual"
transport = Transport.Queue.Redis.create()
channel = Channel.create transport,  "hello"

channel.emit message: "Hello, World"
```

Again, the only code we needed to change is to create a different type of transport.

Using a `Queue` channel, you can implement Workers.

**Worker**
```coffee
{Channel, Transport} = require "mutual"
transport = Transport.Queue.Redis.create()
tasks = Channel.create transport,  "hello-world-tasks"
results = Channel.create transport,  "hello-world-results"

tasks.on task: ({name}) ->
  results.emit result: "Hello, #{name}"
```

**Dispatcher**
```coffee
{Channel, Transport} = require "mutual"
transport = Transport.Queue.Redis.create()
tasks = Channel.create transport,  "hello-world-tasks"
results = Channel.create transport,  "hello-world-results"

tasks.emit task: name: "World"
results.on result: (greeting) ->
  assert greeting == "Hello, World"
```

Let's implement a simple long-polling chat API using Queue channels.

**Server**
```coffee
{Builder} = require "pbx-builder"
{processor} = require "pbx-processor"
{async, partial} = require "fairmont"

builder = Builder.create "chat-api"
builder.define "message",
  template: "/{channel}"
.get()
.post()
.base_url "localhost:8080"

transport = Transport.local
make_channel = partial Channel.create transport

channels = new Proxy {},
    get: (ch, name) -> ch[name] ?= make_channel name

handlers =

  get: async ({respond, match: {path: {channel}}}) ->
    channels[channel].once message: (body) -> respond 200, body

  post: async ({data, respond, match: {path: {channel}}}) ->
    channels[channel].emit message: yield data
    respond 200

call ->
  (require "http")
  .createServer yield (processor api, handlers)
  .listen 8080
```

**Client**
```coffee
{client} = require "pbx-client"
{call, stream, join} = require "fairmont"
api = yield client.discover "localhost:8080"
call ->
  while true
    try
      message = yield join stream yield api.get()
      console.log message
    catch error
      # probably a timeout, just poll again
call ->
  each api.post, stream lines process.stdin
```

If you run the server and the client, you can type your messages via standard input and they'll be echoed back to you as the message comes back to the server.

If we change one line, we can add servers to increase our message throughput. If we change the `Broadcast.Redis` transport, we can run a hundred of these servers behind a load-balancer and scale to hundreds of thousands of messages per second, without changing any other code.
