{randomKey} = require "key-forge"
EventChannel = require "./event-channel"
RemoteQueue = require "./remote-queue"

class DurableChannel extends EventChannel

  constructor: (options) ->
    super
    
    {@name, @transport, @adapter, @timeoutMonitorFrequency} = options

    unless @name?
      throw new Error "Durable channels cannot be anonymous"

    @timeoutMonitor = null
    @timeoutMonitorFrequency ?= 1000

    @store = null
    @queue = new RemoteQueue
      name: "#{@name}.queue"
      transport: @transport
    @queue.listen().on "success", => 
      @startListening()
      @fire event: "ready"

    @destinationStores = {}
    @destinationQueues = {}

    @monitorTimeouts()

    @events = new EventChannel

  package: ({content, to, requestId, timeout}) ->
    message = 
      id: randomKey(16)
      requestId: requestId
      from: @name
      to: to
      timeout: timeout
      content: content

  getStore: ->
    if @store?
      @store
    else
      @events.source (events) =>
        do @events.serially (go) =>
          go => @adapter.collection "#{@name}.messages"
          go (@store) => events.emit "success", @store

  getDestinationStore: (name) ->
    if @destinationStores[name]?
      @destinationStores[name]
    else
      @events.source (events) =>
        do @events.serially (go) =>
          go => @adapter.collection "#{name}.messages"
          go (store) => 
            @destinationStores[name] = store
            events.emit "success", store

  getDestinationQueue: (name) ->
    @destinationQueues[name] ?= new RemoteQueue
      name: "#{name}.queue"
      transport: @transport
    @destinationQueues[name]

  setMessageTimeout: (channel, id, timeout) ->
    if channel? and id? and timeout?
      @events.source (events) =>
        @adapter.client.zadd(
          ["#{@name}.pending", (Date.now() + timeout), "#{channel}::#{id}"], 
          events.callback
        )

  clearMessageTimeout: (channel, id) ->
    if id?
      @events.source (events) =>
        @adapter.client.zrem(
          ["#{@name}.pending", "#{channel}::#{id}"]
          events.callback
        )

  monitorTimeouts: ->
    loopToMonitor = =>
      do @events.serially (go) =>
        go =>
          @events.source (events) =>
            @adapter.client.zrangebyscore(
              ["#{@name}.pending", 0, Date.now()]
              events.callback
            )
        go (expiredMessages) => 
          return if expiredMessages.length == 0
          @events.source (events) =>
            returned = 0
            for expiredMessage in expiredMessages
              expiredMessageTokens = expiredMessage.split("::")
              _events = @expireMessage(expiredMessageTokens[0], expiredMessageTokens[1])
              _events.on "success", ->
                returned++
                events.emit("success") if returned == expiredMessages.length
              _events.on "error", (err) -> events.emit "error", err
        go => 
          @timeoutMonitor = setTimeout(loopToMonitor, @timeoutMonitorFrequency)

    @timeoutMonitor = setTimeout(loopToMonitor, @timeoutMonitorFrequency)

  expireMessage: (channel, id) ->
    @events.source (events) =>

      store = null
      message = null
      do @events.serially (go) =>
        go => @getDestinationStore channel
        go (_store) => 
          store = _store
          store.get(id)
        go (_message) => 
          message = _message
          if message?
            store.delete id
        go => @clearMessageTimeout channel, id
        go =>
          if message?
            @fire event: "timeout", content: {content: message.content, requestId: message.requestId}
          events.emit "success"

  send: ({content, to, timeout}) ->
    @events.source (events) =>
      message = @package({content, to, timeout})
      do @events.serially (go) =>
        go => @getDestinationStore(to)
        go (store) => store.put message.id, message
        go => @getDestinationQueue(to).emit("message", message.id)
        go => @setMessageTimeout to, message.id, message.timeout
        go => events.emit "success"

  reply: ({message, response, timeout}) ->
    @events.source (events) =>
      request = null
      do @events.serially (go) =>
        go => @getStore()
        go (store) => store.get message.requestId
        go (_request) => 
          request = _request
          message = @package({content: response, to: request.from, requestId: message.requestId, timeout})
          @getDestinationStore(request.from)
        go (store) => store.put(message.id, message)
        go => @getDestinationQueue(request.from).emit("message", message.id)
        go => @setMessageTimeout request.from, message.id, message.timeout
        go => events.emit "success"

  close: (message) ->
    @events.source (events) =>
      request = null
      do @events.serially (go) =>
        go => @getStore()
        go (store) => store.delete message.responseId
        go => events.emit "success"

  startListening: ->
    @queue.on "message", (messageId) =>
      message = null
      do @events.serially (go) =>
        go => @getStore()
        go (store) => store.get messageId
        go (_message) => 
          message = _message
          @clearMessageTimeout(message.from, message.requestId) if message.requestId?
        go =>
          @getDestinationStore(message.from) if message.requestId?
        go (store) =>
          store.delete(message.requestId) if message.requestId?
        go => 
          _message = content: message.content
          _message.requestId = (if message.requestId? then message.requestId else message.id)
          _message.responseId = message.id if message.requestId?
          @fire event: "message", content: _message

  end: -> 
    clearTimeout @timeoutMonitor
    @adapter.close()
    @queue.end()
    # remote queue is waiting for messages
    # emit a dummy event so queue can end
    @queue.emit "shutdown" if @queue.isListening
    for key,queue of @destinationQueues
      queue.end()

module.exports = DurableChannel