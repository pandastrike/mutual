Pattern = require "./pattern"

class PatternSet

  constructor: ->
    @_patterns = {}

  add: (specification) ->
    @_patterns[specification] ?= new Pattern specification

  remove: (specification) ->
    delete @_patterns[specification]

  # Callback is optional - returns an array of matches,
  # invoking the callback for each one if provided. Allows
  # for one-pass processing.
  match: (target, callback) ->
    results = []
    for specification, pattern of @_patterns
      if pattern.match target
        callback specification if callback?
        results.push specification
    results
    
module.exports = PatternSet