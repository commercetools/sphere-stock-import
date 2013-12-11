fs = require 'fs'
Config = require '../config'
StockXmlImport = require('../main').StockXmlImport

Config.timeout = 120000
stockxmlimport = new StockXmlImport Config

# get file name from command line option
fileName = ''
process.argv.forEach (val, index, array) ->
  fileName = val if index is 2

fs.readFile fileName, 'utf8', (err, content) ->
  if err
    console.error 'Problems on reading file: ' + error
    process.exit 1
  stockxmlimport.run content, (result) ->
    if not result.message.status
      console.log result