{randomKey} = require "key-forge"
{Redis} = require "pirate"
EventChannel = require "./event-channel"
RemoteQueue = require "./remote-queue"
Transport = require "./redis-transport"

class DurableChannel extends EventChannel

  constructor: (options) ->
    super
    
    {@name, @timeoutMonitorFrequency, @transport} = options

    unless @name?
      throw new Error "Durable channels cannot be anonymous"

    @timeoutMonitor = null
    @timeoutMonitorFrequency ?= 1000

    @events = new EventChannel

    @isTransportShared = true
    unless @transport?
      @isTransportShared = false
      @transport = new Transport
        host: options.redis.host
        port: options.redis.port
      @transport.events.forward @events

    @queue = new RemoteQueue
      name: "#{@name}.queue"
      transport: @transport

    @monitorTimeouts()

    # this isn't necessary but for backward compatibility of interface
    setImmediate => @fire event: "ready"

  package: ({content, to, requestId, timeout}) ->
    message = 
      id: randomKey(16)
      requestId: requestId
      from: @name
      to: to
      timeout: timeout
      content: content

  getMessage: (channel, id) ->
    @events.source (events) =>
      @transport._acquire (client) =>
        client.hget(
          "#{channel}.messages", id,
          (err, data) =>
            @transport._release client
            events.callback(err, if data? then JSON.parse(data) else null)
        )

  putMessage: (channel, id, message) ->
    @events.source (events) =>
      @transport._acquire (client) =>
        client.hset(
          "#{channel}.messages", id, JSON.stringify(message), 
          (err, data) =>
            @transport._release client
            events.callback(err, data)
        )

  deleteMessage: (channel, id) ->
    @events.source (events) =>
      @transport._acquire (client) =>
        client.hdel(
          "#{channel}.messages", id, 
          (err, data) =>
            @transport._release client
            events.callback(err, data)
        )

  getDestinationQueue: (name) ->
    queue = new RemoteQueue
      name: "#{name}.queue"
      transport: @transport

  setMessageTimeout: (name, channel, id, timeout) ->
    if channel? and id? and timeout?
      @events.source (events) =>
        @transport._acquire (client) =>
          client.zadd(
            ["#{name}.pending", (Date.now() + timeout), "#{channel}::#{id}"], 
            (err, data) =>
              @transport._release client
              events.callback(err, data)
          )

  clearMessageTimeout: (name, channel, id) ->
    if id?
      @events.source (events) =>
        @transport._acquire (client) =>
          client.zrem(
            ["#{name}.pending", "#{channel}::#{id}"]
            (err, data) =>
              @transport._release client
              events.callback(err, data)
          )

  getMessageTimeout: (name, channel, id) ->
    if id?
      @events.source (events) =>
        @transport._acquire (client) =>
          client.zscore(
            ["#{name}.pending", "#{channel}::#{id}"]
            (err, data) =>
              @transport._release client 
              events.callback(err, data)
          )

  monitorTimeouts: ->
    loopToMonitor = =>
      do @events.serially (go) =>
        go =>
          @events.source (events) =>
            @transport._acquire (client) =>
              client.zrangebyscore(
                ["#{@name}.pending", 0, Date.now()]
                (err, data) =>
                  @transport._release client 
                  events.callback(err, data)
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
    message = null
    do @events.serially (go) =>
      go => @getMessage channel, id
      go (_message) => 
        message = _message
        @getMessageTimeout @name, channel, id
      go (timeout) =>
        # if reply was sent in the meantime, timeout would have been cleared, we shouldn't fire timeout if it was replied
        return unless timeout?
        do @events.serially (go) =>
          go =>
            if message?
              @deleteMessage channel, id
          go => @clearMessageTimeout @name, channel, id
          go =>
            if message?
              @fire event: "timeout", content: {content: message.content, requestId: message.requestId}

  send: ({content, to, timeout}) ->
    message = @package({content, to, timeout})
    do @events.serially (go) =>
      go => @putMessage to, message.id, message
      go => @setMessageTimeout @name, to, message.id, message.timeout
      go => @getDestinationQueue(to).emit("message", message.id)

  reply: ({message, response, timeout}) ->
    do @events.serially (go) =>
      go => @getMessage @name, message.requestId
      go (request) =>
        # its possible that this is a reply to a message that already timed out
        return null unless request?
        
        message = @package({content: response, to: request.from, requestId: message.requestId, timeout})
        do @events.serially (go) =>
          go => @clearMessageTimeout(request.from, @name, message.requestId)
          go => @putMessage request.from, message.id, message
          go => @setMessageTimeout @name, request.from, message.id, message.timeout
          go => @getDestinationQueue(request.from).emit("message", message.id)

  close: (message) ->
    do @events.serially (go) =>
      go => @deleteMessage @name, message.responseId
      go => @clearMessageTimeout(message.to, message.from, message.responseId)

  listen: ->
    @events.source (events) =>
      @queue.listen().on "success", => 
        messageHandler = (messageId) =>
          do @events.serially (go) =>
            go => @getMessage @name, messageId
            go (message) =>
              # its possible that this message has already timed out and no longer available in the store
              return null unless message?

              return message unless message.requestId?

              @events.source (events) =>
                do @events.serially (go) =>
                  go => @getMessage message.from, message.requestId
                  go (request) =>
                    do @events.serially (go) =>
                      go => 
                        if request?
                          # now that we got the reply, we can delete the original request
                          @deleteMessage message.from, message.requestId
                        else
                          # request has timed out, we should close it as the sender won't receive this message
                          @deleteMessage @name, messageId
                      go => 
                        events.emit("success", (if request? then message else null))
            go (message) =>
              if message?
                _message = content: message.content
                _message.from = if message.requestId? then message.to else message.from
                _message.to = if message.requestId? then message.from else message.to
                _message.requestId = if message.requestId? then message.requestId else message.id
                _message.responseId = message.id if message.requestId?
                @fire event: "message", content: _message
            go =>
              if @channels["message"]?.handlers?.length > 0
                @queue.once("message", messageHandler)

        @superOn ?= @on
        @on = (event, handler) =>
          @superOn event, handler
          if event == "message"
            @queue.once "message", messageHandler

        events.emit "success"

  end: -> 
    clearTimeout @timeoutMonitor
    @queue.end(!@isTransportShared)

module.exports = DurableChannel