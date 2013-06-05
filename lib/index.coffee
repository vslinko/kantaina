_ = require "lodash"
w = require "when"


parseArguments = (f) ->
  f.toString()
    .match(/function\s+\w*\s*\((.*?)\)/)[1]
    .split(/\s*,\s*/)
    .filter((arg) -> arg.length > 0)


class Container
  constructor: ->
    @dependencies = {}
    @factories = {}
    @values = {}

  set: (key, value) ->
    if _.isFunction value
      @dependencies[key] = parseArguments value
      @factories[key] = value

      for dependency in @dependencies[key]
        if @dependencies.hasOwnProperty dependency
          if key in @dependencies[dependency]
            throw new Error "Сircular dependency: #{key} <-> #{dependency}"

    else
      @values[key] = value

  get: (keys) ->
    if _.isArray keys
      @_getMany keys
    else
      @_getOne keys

  inject: (factory, dependencies) ->
    =>
      dependencies = parseArguments factory unless dependencies
      deferred = w.defer()

      @_getMany(dependencies).then (dependencies) ->
        deferred.resolve factory.apply null, dependencies

      deferred.promise

  _getOne: (key) ->
    deferred = w.defer()

    if @values.hasOwnProperty key
      deferred.resolve @values[key]

    else if _.isFunction @factories[key]
      @values[key] = @inject(@factories[key], @dependencies[key])()
      @values[key].then (value) =>
        @values[key] = value
        deferred.resolve value

    else
      deferred.resolve undefined

    deferred.promise

  _getMany: (keys) ->
    promises = keys.map (key) =>
      @_getOne key

    w.all promises


module.exports = ->
  new Container

module.exports.Container = Container
