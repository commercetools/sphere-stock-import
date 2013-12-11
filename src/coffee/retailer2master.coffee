_ = require('underscore')._
StockXmlImport = require('../main').StockXmlImport
Rest = require('sphere-node-connect').Rest
Q = require 'q'

class MarketPlaceStockUpdater extends StockXmlImport
  constructor: (@options, @retailerProjectKey, @retailerClientId, @retailerClientSecret) ->
    super @options
    @retailerRest = new Rest config: {
      project_key: @retailerProjectKey
      client_id: @retailerClientId
      client_secret: @retailerClientSecret
    }

  initMatcher: () ->
    deferred = Q.defer()
    Q.all([@ensureRetailerChannelInMaster(), @retailerProducts(), @allStocks(@rest)])
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

  ensureRetailerChannelInMaster: () ->
    deferred = Q.defer()
    @rest.GET "/channels?query=" + encodeURIComponent("key=\"#{@retailerProjectKey}\""), (error, response, body) =>
      if error
        deferred.reject "Error: " + error
        return deferred.promise
      if response.statusCode == 200
        channels = JSON.parse(body).results
        if channels.length is 1
          deferred.resolve channels[0].id
          return deferred.promise
      # let's create the channel for the retailer in master project
      c =
        key: @retailerProjectKey
      @rest.POST "/channels", JSON.stringify(c), (error, response, body) ->
        if error
          deferred.reject "Error: " + error
        else if response.statusCode == 201
          id = JSON.parse(body).id
          deferred.resolve id
        else
          deferred.reject "Problem: " + body
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