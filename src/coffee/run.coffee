fs = require 'fs'
package_json = require '../package.json'
StockImport = require '../lib/stockimport'
argv = require('optimist')
  .usage('Usage: $0 --projectKey [key] --clientId [id] --clientSecret [secret] --file [file]')
  .default('timeout', 60000)
  .describe('projectKey', 'your SPHERE.IO project-key')
  .describe('clientId', 'your OAuth client id for the SPHERE.IO API')
  .describe('clientSecret', 'your OAuth client secret for the SPHERE.IO API')
  .describe('file', 'XML or CSV file containing inventory information to import')
  .describe('timeout', 'Set timeout for requests')
  .demand(['projectKey', 'clientId', 'clientSecret', 'file'])
  .argv

options =
  config:
    project_key: argv.projectKey
    client_id: argv.clientId
    client_secret: argv.clientSecret
  timeout: argv.timeout
  user_agent: "#{package_json.name} - #{package_json.version}"
  logConfig:
    streams: [
      { level: 'warn', stream: process.stderr }
      { level: 'warn', path: './sphere-stock-import.log' }
    ]

stockimport = new StockImport options

fileName = argv.file
mode = stockimport.getMode fileName

fs.readFile fileName, 'utf8', (err, content) ->
  if err?
    logger.error "Problems on reading file '#{fileName}': #{err}"
    process.exit 2
  stockimport.run(content, mode)
  .then (result) ->
    console.info stockimport.sumResult(result)
    process.exit 0
  .fail (err) ->
    logger.error err
    process.exit 1
