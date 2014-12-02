{promise} = require "when"
EventChannel = require "./event-channel"

module.exports = class Promiseifier

  @wrap: (f) ->
    unless typeof f == "function"
      f
    else
      ->
        rVal = f.apply @, arguments
        if rVal instanceof EventChannel
          promise (resolve, reject) ->
            rVal.on "success", (data) -> resolve(data)
            rVal.on "error", (err) -> reject(err)
        else
          promise (resolve, reject) ->
            resolve(rVal)

  @promiseify: (evented) ->
    promised = new Object(evented)
    promised[k] = Promiseifier.wrap(f) for k,f of evented
    if evented.prototype?
      promised.prototype = Promiseifier.promiseify(evented.prototype)
    promised
