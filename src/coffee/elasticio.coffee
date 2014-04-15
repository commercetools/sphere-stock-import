package_json = require '../package.json'
Logger = require './logger'
StockImport = require './stockimport'
bunyanLogentries = require 'bunyan-logentries'

exports.process = (msg, cfg, next, snapshot) ->
  logStreams = [
    { level: 'warn', stream: process.stderr }
  ]

  if cfg.logentriesToken?
    logStreams.push
      level: 'info'
      stream: bunyanLogentries.createStream token: cfg.logentriesToken
      type: 'raw'

  logger = new Logger streams: logStreams

  opts =
    config:
      client_id: cfg.sphereClientId
      client_secret: cfg.sphereClientSecret
      project_key: cfg.sphereProjectKey
    timeout: 60000
    user_agent: "#{package_json.name} - elasticio - #{package_json.version}",
    logConfig:
      logger: logger
    csvHeaders: 'sku, quantity'
    csvDelimiter: ','

  stockimport = new StockImport opts
  stockimport.elasticio msg, cfg, next, snapshot
