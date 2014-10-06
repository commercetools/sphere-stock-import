{ExtendedLogger} = require 'sphere-node-utils'
bunyanLogentries = require 'bunyan-logentries'
package_json = require '../package.json'
StockImport = require './stockimport'

exports.process = (msg, cfg, next, snapshot) ->
  logStreams = [
    { level: 'warn', stream: process.stderr }
  ]

  if cfg.logentriesToken?
    logStreams.push
      level: 'info'
      stream: bunyanLogentries.createStream token: cfg.logentriesToken
      type: 'raw'

  logger = new ExtendedLogger
    additionalFields:
      project_key: cfg.sphereProjectKey
    logConfig:
      name: "#{package_json.name}-#{package_json.version}"
      streams: logStreams

  opts =
    config:
      client_id: cfg.sphereClientId
      client_secret: cfg.sphereClientSecret
      project_key: cfg.sphereProjectKey
    timeout: 60000
    user_agent: "#{package_json.name} - elasticio - #{package_json.version}",
    csvHeaders: 'sku, quantity'
    csvDelimiter: ','

  stockimport = new StockImport logger, opts
  stockimport.elasticio msg, cfg, next, snapshot
