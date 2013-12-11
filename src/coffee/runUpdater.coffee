Config = require '../config'
MarketPlaceStockUpdater = require('../main').MarketPlaceStockUpdater

Config.timeout = 120000

retailerProjectKey = ''
retailerClientId = ''
retailerClientSecret = ''
process.argv.forEach (val, index, array) ->
  retailerProjectKey = val if index is 2
  retailerClientId = val if index is 3
  retailerClientSecret = val if index is 4

updater = new MarketPlaceStockUpdater(Config, retailerProjectKey, retailerClientId, retailerClientSecret)

updater.allStocks(updater.retailerRest).then (retailerStock) ->
  updater.initMatcher().then () ->
    updater.createOrUpdate retailerStock, (res) ->
      console.log res