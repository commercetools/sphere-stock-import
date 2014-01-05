fs = require 'fs'
Config = require '../config'
argv = require('optimist')
  .usage('Usage: $0 --xmlfile file')
  .demand(['xmlfile'])
  .argv
StockXmlImport = require('../main').StockXmlImport

stockxmlimport = new StockXmlImport Config

fs.readFile argv.xmlfile, 'utf8', (err, content) ->
  if err
    console.error 'Problems on reading file: ' + error
    process.exit 2
  stockxmlimport.run content, (result) ->
    console.log result
    process.exit 1 unless result.status