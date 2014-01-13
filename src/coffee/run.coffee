StockXmlImport = require('../main').StockXmlImport
fs = require 'fs'
argv = require('optimist')
  .usage('Usage: $0 --projectKey key --clientId id --clientSecret secret --xmlfile file')
  .demand(['projectKey', 'clientId', 'clientSecret', 'xmlfile'])
  .argv

options =
  config:
    project_key: argv.project_key
    client_id: argv.clientId
    client_secret: argv.clientSecret

stockxmlimport = new StockXmlImport options

fs.readFile argv.xmlfile, 'utf8', (err, content) ->
  if err
    console.error "Problems on reading file '#{argv.xmlfile}': " + error
    process.exit 2
  stockxmlimport.run content, (result) ->
    console.log result
    process.exit 1 unless result.status