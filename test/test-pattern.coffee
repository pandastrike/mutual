Testify = require "testify"
assert = require "assert"

# w = (string) ->
#   string.split(".")

w = (string) -> string
  
Pattern = require "../src/pattern"

Testify.test "A Pattern", (context) ->

  context.test "with no wildcards matches", ->
    pattern = new Pattern w "foo.bar"
    assert.ok pattern.match w "foo.bar"

  context.test "with a trailing wildcard matches", ->
    pattern = new Pattern w "foo.*"
    assert.ok pattern.match w "foo.bar"

  context.test "with a leading wildcard matches", ->
    pattern = new Pattern w "*.bar"
    assert.ok pattern.match w "foo.bar"

  context.test "consisting of a single wild-card matches", ->
    pattern = new Pattern w "*"
    assert.ok pattern.match w "foo.bar"

Testify.test "A mismatched Pattern", (context) ->

  context.test "with no wildcards doesn't match", ->
    pattern = new Pattern w "bar.foo"
    assert.ok !pattern.match w "foo.bar"

  context.test "with a trailing wildcard doesn't match", ->
    pattern = new Pattern w "bar.*"
    assert.ok !pattern.match w "foo.bar"

  context.test "with a leading wildcard doesn't match", ->
    pattern = new Pattern w "*.foo"
    assert.ok !pattern.match  w "foo.bar"

Testify.test "A long Pattern", (context) ->

  context.test "with no wildcards matches", ->
    pattern = new Pattern w "foo.bar.baz"
    assert.ok pattern.match  w "foo.bar.baz"

  context.test "with a leading wildcard matches", ->
    pattern = new Pattern w "*.bar.baz"
    assert.ok pattern.match  w "foo.bar.baz"

  context.test "with a leading wildcard matches multiple elements", ->
    pattern = new Pattern w "*.baz"
    assert.ok pattern.match  w "foo.bar.baz"

  context.test "with a middle wildcard matches", ->
    pattern = new Pattern w "foo.*.baz"
    assert.ok pattern.match  w "foo.bar.baz"

  context.test "with a middle wildcard matches multiple elements", ->
    pattern = new Pattern w "foo.*.baz"
    assert.ok pattern.match  w "foo.bar-1.bar-2.baz"


Testify.test "A long mismatched Pattern", (context) ->

  context.test "with a trailing wildcard doesn't match", ->
    pattern = new Pattern w "bar.foo.*"
    assert.ok !pattern.match  w "foo.bar.baz"

  context.test "with a leading wildcard doesn't match", ->
    pattern = new Pattern w "*.foo"
    assert.ok !pattern.match  w "foo.bar.baz"

  context.test "with a leading wildcard doesn't match (no common elements)", ->
    pattern = new Pattern w "*.foo"
    assert.ok !pattern.match  w "blurg.bar.baz"

  context.test "with a middle wildcard doesn't match", ->
    pattern = new Pattern w "foo.*.bar"
    assert.ok !pattern.match  w "foo.bar.baz"

  context.test "with zero wildcard matches doesn't match", ->
    pattern = new Pattern w "*.foo.bar.baz"
    assert.ok !pattern.match w "foo.bar.baz"
