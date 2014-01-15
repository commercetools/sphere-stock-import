StockXmlImport = require('../main').StockXmlImport
fs = require 'fs'
argv = require('optimist')
  .usage('Usage: $0 --projectKey key --clientId id --clientSecret secret --xmlfile file --timeout timeout')
  .demand(['projectKey', 'clientId', 'clientSecret', 'xmlfile'])
  .argv

timeout = argv.timeout
timeout or= 60000

options =
  config:
    project_key: argv.projectKey
    client_id: argv.clientId
    client_secret: argv.clientSecret
  timeout: timeout

stockxmlimport = new StockXmlImport options

fs.readFile argv.xmlfile, 'utf8', (err, content) ->
  if err
    console.error "Problems on reading file '#{argv.xmlfile}': " + err
    process.exit 2
  stockxmlimport.run content, (result) ->
    console.log result
    process.exit 1 unless result.status