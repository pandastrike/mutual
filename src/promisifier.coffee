{promise} = require "when"
EventChannel = require "./event-channel"

module.exports = class Promisifier

  @wrap: (f) ->
    unless typeof f == "function"
      f
    else
      ->
        rVal = f.apply @, arguments
        if rVal instanceof EventChannel
          promise (resolve, reject) ->
            _err = null
            rVal.on "error", (err) -> _err = err
            rVal.on "*", (data) ->
              unless _err?
                resolve(data)
              else
                reject(_err)
        else
          promise (resolve, reject) ->
            resolve(rVal)

  @promisify: (evented) ->
    promised = new Object(evented)
    promised[k] = Promisifier.wrap(f) for k,f of evented
    if evented.prototype?
      promised.prototype = Promisifier.promisify(evented.prototype)
    promised
