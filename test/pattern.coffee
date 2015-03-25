Amen = require "amen"
assert = require "assert"

# w = (string) ->
#   string.split(".")

w = (string) -> string

Pattern = require "../src/pattern"

Amen.describe "A Pattern", (context) ->

  context.test "with no wildcards matches", ->
    pattern = new Pattern w "foo.bar"
    assert pattern.match w "foo.bar"

  context.test "with a trailing wildcard matches", ->
    pattern = new Pattern w "foo.*"
    assert pattern.match w "foo.bar"

  context.test "with a leading wildcard matches", ->
    pattern = new Pattern w "*.bar"
    assert pattern.match w "foo.bar"

  context.test "consisting of a single wild-card matches", ->
    pattern = new Pattern w "*"
    assert pattern.match w "foo.bar"

Amen.describe "A mismatched Pattern", (context) ->

  context.test "with no wildcards doesn't match", ->
    pattern = new Pattern w "bar.foo"
    assert !pattern.match w "foo.bar"

  context.test "with a trailing wildcard doesn't match", ->
    pattern = new Pattern w "bar.*"
    assert !pattern.match w "foo.bar"

  context.test "with a leading wildcard doesn't match", ->
    pattern = new Pattern w "*.foo"
    assert !pattern.match  w "foo.bar"

Amen.describe "A long Pattern", (context) ->

  context.test "with no wildcards matches", ->
    pattern = new Pattern w "foo.bar.baz"
    assert pattern.match  w "foo.bar.baz"

  context.test "with a leading wildcard matches", ->
    pattern = new Pattern w "*.bar.baz"
    assert pattern.match  w "foo.bar.baz"

  context.test "with a leading wildcard matches multiple elements", ->
    pattern = new Pattern w "*.baz"
    assert pattern.match  w "foo.bar.baz"

  context.test "with a middle wildcard matches", ->
    pattern = new Pattern w "foo.*.baz"
    assert pattern.match  w "foo.bar.baz"

  context.test "with a middle wildcard matches multiple elements", ->
    pattern = new Pattern w "foo.*.baz"
    assert pattern.match  w "foo.bar-1.bar-2.baz"


Amen.describe "A long mismatched Pattern", (context) ->

  context.test "with a trailing wildcard doesn't match", ->
    pattern = new Pattern w "bar.foo.*"
    assert !pattern.match  w "foo.bar.baz"

  context.test "with a leading wildcard doesn't match", ->
    pattern = new Pattern w "*.foo"
    assert !pattern.match  w "foo.bar.baz"

  context.test "with a leading wildcard doesn't match (no common elements)", ->
    pattern = new Pattern w "*.foo"
    assert !pattern.match  w "blurg.bar.baz"

  context.test "with a middle wildcard doesn't match", ->
    pattern = new Pattern w "foo.*.bar"
    assert !pattern.match  w "foo.bar.baz"

  context.test "with zero wildcard matches doesn't match", ->
    pattern = new Pattern w "*.foo.bar.baz"
    assert !pattern.match w "foo.bar.baz"
