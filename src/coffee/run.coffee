fs = require 'fs'
package_json = require '../package.json'
StockXmlImport = require('../main').StockXmlImport
argv = require('optimist')
  .usage('Usage: $0 --projectKey [key] --clientId [id] --clientSecret [secret] --file [file]')
  .default('timeout', 300000)
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

stockxmlimport = new StockXmlImport options

fileName = argv.file
mode =
  if /\.xml$/i.test fileName
    'XML'
  else if /\.csv$/i.test fileName
    'CSV'
  else
    'UNKNOWN'

if mode? is 'UNKNOWN'
  console.error "Don't know how to import #{fileName}. Please provide an XML or CSV file."
  process.exit 9

fs.readFile fileName, 'utf8', (err, content) ->
  if err
    console.error "Problems on reading file '#{fileName}': " + err
    process.exit 2
  stockxmlimport.run content, mode, (result) ->
    if result.status
      console.log result
      process.exit 0
    console.error result
    process.exit 1
