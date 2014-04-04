{randomKey} = require "key-forge"
EventChannel = require "./event-channel"
RemoteQueue = require "./remote-queue"

class DurableChannel extends EventChannel

  constructor: (options) ->
    super
    
    {@name, @transport, @adapter, @timeoutMonitorFrequency} = options

    unless @name?
      throw new Error "Durable channels cannot be anonymous"

    @timeoutHandlers = {}
    @timeoutMonitor = null
    @timeoutMonitorFrequency ?= 1000

    @store = null
    @queue = new RemoteQueue
      name: "#{@name}.queue"
      transport: @transport

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

  setMessageTimeout: (id, timeout, store, callback) ->
    if id? and timeout?
      @events.source (events) =>
        @timeoutHandlers[id] = {store, callback}
        @adapter.client.zadd(
          ["#{@name}.pending", (Date.now() + timeout), id], 
          events.callback
        )

  clearMessageTimeout: (id) ->
    if id?
      @events.source (events) =>
        delete @timeoutHandlers[id]
        @adapter.client.zrem(
          ["#{@name}.pending", id]
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
        go (expiredMessageIds) => 
          return if expiredMessageIds.length == 0
          @events.source (events) =>
            returned = 0
            for messageId in expiredMessageIds
              _events = @expireMessage(messageId)
              _events.on "success", ->
                returned++
                events.emit("success") if returned == expiredMessageIds.length
              _events.on "error", (err) -> events.emit "error", err
        go => 
          @timeoutMonitor = setTimeout(loopToMonitor, @timeoutMonitorFrequency)

    @timeoutMonitor = setTimeout(loopToMonitor, @timeoutMonitorFrequency)

  expireMessage: (id) ->
    @events.source (events) =>

      timeoutHandler = @timeoutHandlers[id]
      if !timeoutHandler?
        return events.emit "success"

      store = null
      message = null
      do @events.serially (go) =>
        go => @getDestinationStore timeoutHandler.store
        go (_store) => 
          store = _store
          store.get(id)
        go (_message) => 
          message = _message
          if message?
            store.delete id
        go => @clearMessageTimeout id
        go =>
          if message?
            timeoutHandler.callback?({content: message.content, requestId: message.requestId})
          events.emit "success"

  send: ({content, to, timeout}, timeoutCallback) ->
    @events.source (events) =>
      message = @package({content, to, timeout})
      do @events.serially (go) =>
        go => @getDestinationStore(to)
        go (store) => store.put message.id, message
        go => @getDestinationQueue(to).emit("message", message.id)
        go => @setMessageTimeout message.id, message.timeout, to, timeoutCallback
        go => events.emit "success"

  reply: ({message, response, timeout}, timeoutCallback) ->
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
        go => @setMessageTimeout message.id, message.timeout, request.from, timeoutCallback
        go => events.emit "success"

  close: (message) ->
    @events.source (events) =>
      request = null
      do @events.serially (go) =>
        go => @getStore()
        go (store) => store.delete message.responseId
        go => events.emit "success"

  listen: ->
    @events.source (events) =>
      @queue.listen().on "success", =>
        @queue.on "message", (messageId) =>
          message = null
          do @events.serially (go) =>
            go => @getStore()
            go (store) => store.get messageId
            go (_message) => 
              message = _message
              @clearMessageTimeout(message.requestId) if message.requestId?
            go =>
              @getDestinationStore(message.from) if message.requestId?
            go (store) =>
              store.delete(message.requestId) if message.requestId?
            go => 
              _message = content: message.content
              _message.requestId = (if message.requestId? then message.requestId else message.id)
              _message.responseId = message.id if message.requestId?
              events.emit "message", _message

        events.emit "ready"
  
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