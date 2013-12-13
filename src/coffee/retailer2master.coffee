_ = require('underscore')._
StockXmlImport = require('../main').StockXmlImport
Rest = require('sphere-node-connect').Rest
Q = require 'q'

class MarketPlaceStockUpdater extends StockXmlImport
  constructor: (@options, @retailerProjectKey, @retailerClientId, @retailerClientSecret) ->
    super @options
    c =
      project_key: @retailerProjectKey
      client_id: @retailerClientId
      client_secret: @retailerClientSecret
    @retailerRest = new Rest config: c

  run: () ->
    @allStocks(@retailerRest).then (retailerStock) =>
      @initMatcher().then () =>
        @createOrUpdate retailerStock, (res) =>
          @returnResult true, res
      .fail (msg)->
        @returnResult false, msg
    .fail (msg)->
      @returnResult false, msg

  initMatcher: () ->
    deferred = Q.defer()
    Q.all([@ensureChannel(@retailerProjectKey), @retailerProducts(), @allStocks(@rest)])
    .then ([channelId, retailerProducts, masterStocks]) =>
      @existingStocks = masterStocks

      master2retailer = {}
      for p in retailerProducts
        _.extend(master2retailer, @matchVariant(p.masterData.current.masterVariant))
        for v in p.masterData.current.variants
          _.extend(master2retailer, @matchVariant(v))

      for es, i in masterStocks
        rSku = master2retailer[es.sku]
        continue if not rSku
        @sku2index[rSku] = i

      deferred.resolve true
    .fail (msg) ->
      deferred.reject msg
    deferred.promise

  retailerProducts: () ->
    deferred = Q.defer()
    @retailerRest.GET "/products?limit=0", (error, response, body) ->
      if error
        deferred.reject "Error: " + error
      else if response.statusCode != 200
        deferred.reject "Problem: " + body
      else
        retailerProducts = JSON.parse(body).results
        deferred.resolve retailerProducts
    deferred.promise

  matchVariant: (variant) ->
    m2r = {}
    rSku = variant.sku
    return m2r if not rSku
    for a in variant.attributes
      continue if a.name != 'mastersku'
      mSku = a.value
      return m2r if not mSku
      m2r[mSku] = rSku
      break
    m2r

  create: (stock, bar) ->
    # We don't create new stock entries for now - only update existing!
    # Idea: create stock only for entries that have a product that have a valid mastersku set
    deferred = Q.defer()
    bar.tick()
    deferred.promise

module.exports = MarketPlaceStockUpdater