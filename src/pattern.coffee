{memoize} = require "fairmont"

_parse = (string) ->
  try
    string.split "."
  catch error
    throw new Error "#{string} is not a valid pattern"

_match = (pattern,target) ->
  pl = pattern.length
  tl = target.length
  if pl is tl is 0
    return true
  else if pl is 0 or tl is 0
    return false
  else
    [p,px...] = pattern
    [t,tx...] = target
    if p is "*"
      if _match px, tx
        return true
      else
        _match pattern, tx
    else if p is t
      _match px, tx
    else
      return false
  
class Pattern
  
  constructor: (pattern) ->
    @_pattern = _parse pattern
    
  match: (target) ->
    @_match ?= memoize (target) =>
      _match @_pattern, (_parse target)
    @_match target
    
module.exports = Pattern