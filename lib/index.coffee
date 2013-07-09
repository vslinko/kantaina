DepGraph = require "dep-graph"
events = require "events"
w = require "when"


parseArguments = (f) ->
  f.toString()
    .match(/function\s+\w*\s*\((.*?)\)/)[1]
    .split(/\s*,\s*/)
    .filter((arg) -> arg.length > 0)


class Container extends events.EventEmitter
  constructor: ->
    @clean()

  set: (key, dependencies, value) ->
    if value is undefined
      value = dependencies
      dependencies = undefined

    if typeof value is "function"
      @factories[key] = value
      delete @values[key]
      delete @graph.map[key]

      # check cyclic dependency
      dependencies = parseArguments value unless dependencies
      @graph.add key, dependency for dependency in dependencies
      @graph.getChain key

      # call factory if any listeners registered
      @get(key) if @listeners(key).length > 0

    else
      @values[key] = value
      @emit key, value

    @

  has: (key) ->
    @values.hasOwnProperty(key) or @factories.hasOwnProperty(key)

  unless: (key, dependencies, value) ->
    @set key, dependencies, value unless @has key
    @

  get: (keys) ->
    getter = (key) =>
      if @values.hasOwnProperty key
        w.resolve @values[key]

      else if @factories[key]
        @values[key] = @inject(@graph.map[key], @factories[key]).then (value) =>
          @values[key] = value
          @emit key, value
          value

      else
        deffered = w.defer()
        @once key, deffered.resolve
        deffered.promise

    if Array.isArray keys
      w.map keys, getter
    else
      getter keys

  inject: (dependencies = [], factory) ->
    if factory is undefined
      factory = dependencies
      dependencies = parseArguments factory

    @get(dependencies).spread factory

  clean: ->
    @graph = new DepGraph
    @factories = {}
    @values = container: @


module.exports = ->
  new Container

module.exports.Container = Container
