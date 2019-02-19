_ = require 'underscore'
Promise = require 'bluebird'

exports.cleanup = (logger, client) ->
  logger.debug 'Deleting old inventory entries...'
  client.inventoryEntries.all().fetch()
    .then (result) ->
      Promise.all _.map result.body.results, (e) ->
        client.inventoryEntries.byId(e.id).delete(e.version)
    .then (results) ->
      logger.debug "Inventory #{_.size results} deleted."
      logger.debug 'Deleting old types entries...'
      client.types.all().fetch()
    .then (result) ->
      Promise.all _.map result.body.results, (e) ->
        client.types.byId(e.id).delete(e.version)
    .then (results) ->
      logger.debug "Types #{_.size results} deleted."
      logger.debug 'Deleting old channels entries...'
      client.channels.all().fetch()
    .then (result) ->
      Promise.all _.map result.body.results, (e) ->
        client.channels.byId(e.id).delete(e.version)
    .then (results) ->
      logger.debug "Channels #{_.size results} deleted."
      Promise.resolve()
