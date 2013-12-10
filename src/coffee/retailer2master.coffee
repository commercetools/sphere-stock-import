_ = require('underscore')._
Config = require("../config")
StockXmlImport = require("../lib/stockxmlimport").StockXmlImport
Rest = require('sphere-node-connect').Rest
Q = require('q')
ProgressBar = require 'progress'

Config.timeout = 120000
stockxmlimport = new StockXmlImport Config

rProjectKey = ""
rClientId = ""
rClientSecret = ""
process.argv.forEach (val, index, array) ->
  rProjectKey = val if index is 2
  rClientId = val if index is 3
  rClientSecret = val if index is 4

rRest = new Rest config: {
  project_key: rProjectKey
  client_id: rClientId
  client_secret: rClientSecret
}

retailerChannelInMaster = () =>
  deferred = Q.defer()
  stockxmlimport.rest.GET "/channels?query=" + encodeURIComponent("key=\"#{rProjectKey}\""), (error, response, body) ->
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
      key: rProjectKey
    stockxmlimport.rest.POST "/channels", JSON.stringify(c), (error, response, body) ->
      if error
        deferred.reject "Error: " + error
      else if response.statusCode == 201
        id = JSON.parse(body).id
        deferred.resolve id
      else
        deferred.reject "Problem: " + body
  deferred.promise

retailerProducts = () ->
  deferred = Q.defer()
  rRest.GET "/products?limit=0", (error, response, body) ->
    if error
      deferred.reject "Error: " + error
    else if response.statusCode != 200
      deferred.reject "Problem: " + body
    else
      retailerProducts = JSON.parse(body).results
      deferred.resolve retailerProducts
  deferred.promise

stocks = (rest) ->
  deferred = Q.defer()
  rest.GET "/inventory?limit=0", (error, response, body) ->
    if error
      deferred.reject "Error: " + error
    else if response.statusCode != 200
      deferred.reject "Problem: " + body
    else
      stocks = JSON.parse(body).results
      deferred.resolve stocks
  deferred.promise

match = (masterStocks, retailerProducts) ->
  master2retailer = {}
  for p in retailerProducts
    _.extend(master2retailer, matchVariant(p.masterData.current.masterVariant))
    for v in p.masterData.current.variants
      _.extend(master2retailer, matchVariant(v))

  console.log "master2retailer: %j", master2retailer
  sku2index = {}
  for es, i in masterStocks
    rSku = master2retailer[es.sku]
    continue if not rSku
    sku2index[rSku] = i

  console.log "s2i: %j", sku2index
  sku2index

matchVariant = (variant) ->
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

stockxmlimport.create = (stock, bar) ->
  # We don't create new stock entries - only update existing!
  deferred = Q.defer()
  bar.tick()
  deferred.promise

Q.all([retailerChannelInMaster(), retailerProducts(), stocks(rRest), stocks(stockxmlimport.rest)])
.then ([channelId, retailerProducts, retailerStocks, masterStocks]) ->
  sku2index = match(masterStocks, retailerProducts)

  posts = []
  bar = new ProgressBar 'Updating stock [:bar] :percent done', { width: 50, total: retailerStocks.length }
  for s in retailerStocks
    s.supplyChannel =
      typeId: 'channel'
      id: channelId

    if sku2index[s.sku] >= 0
      posts.push stockxmlimport.update(s, masterStocks[sku2index[s.sku]], bar)
    else
      posts.push stockxmlimport.create(s, bar)
  
  Q.all(posts).then (v) =>
    if v.length is 1
      v = v[0]
    else
      v = "#{v.length} Done"
    console.log v