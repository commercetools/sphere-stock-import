package_json = require '../package.json'
StockImport = require './stockimport'

exports.process = (msg, cfg, next, snapshot) ->
  config =
    client_id: cfg.sphereClientId
    client_secret: cfg.sphereClientSecret
    project_key: cfg.sphereProjectKey
    timeout: 60000
    user_agent: "#{package_json.name} - elasticio - #{package_json.version}",
    logConfig:
      streams: [
        { level: 'warn', stream: process.stderr }
      ]
  stockimport = new StockImport
    config: config
  stockimport.elasticio msg, cfg, next, snapshot
