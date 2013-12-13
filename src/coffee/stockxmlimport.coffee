_ = require('underscore')._
xmlHelpers = require '../lib/xmlhelpers.js'
InventorySync = require('sphere-node-sync').InventorySync
Q = require 'q'
ProgressBar = require 'progress'

class StockXmlImport
  constructor: (@options) ->
    @sync = new InventorySync @options
    @rest = @sync._rest
    @existingStocks = {}
    @sku2index = {}

  elasticio: (msg, cfg, cb, snapshot) ->
    if msg.attachments
      for attachment of msg.attachments
        continue if not attachment.match /xml$/i
        content = msg.attachments[attachment].content
        continue if not content
        xmlString = new Buffer(content, 'base64').toString()
        @run xmlString, cb
    else if msg.body
      # TODO: As we get only one entry here, we should query for the existing one and not
      # get the whole inventory
      @initMatcher().then () =>
        @createOrUpdate([@createEntry(msg.body.SKU, msg.body.QUANTITY)], cb)
      .fail (msg) =>
        @returnResult false, msg, cb
    else
      @returnResult false, 'No data found in elastic.io msg.', cb

  run: (xmlString, callback) ->
    throw new Error 'String required' unless _.isString xmlString
    throw new Error 'Callback must be a function' unless _.isFunction callback

    xmlHelpers.xmlTransform xmlHelpers.xmlFix(xmlString), (err, result) =>
      if err
        @returnResult false, "Error on parsing XML: " + err, callback
      else
        @ensureChannel().then (channelId) =>
          stocks = @mapStock result.root, channelId
          @initMatcher().then () =>
            @createOrUpdate stocks, callback
          .fail (msg) =>
            @returnResult false, msg, callback
        .fail (msg) =>
          @returnResult false, msg, callback

  returnResult: (positiveFeedback, msg, callback) ->
    d =
      message:
        status: positiveFeedback
        msg: msg
    callback d

  createOrUpdate: (stocks, callback) ->
    posts = []
    bar = new ProgressBar 'Updating stock [:bar] :percent done', { width: 50, total: stocks.length }
    for s in stocks
      es = @match(s)
      if es
        posts.push @update(s, es, bar)
      else
        posts.push @create(s, bar)

    Q.all(posts).then (messages) =>
      if messages.length is 1
        messages = messages[0]
      else
        messages = "#{messages.length} Done"
      @returnResult true, messages, callback
    .fail (msg) =>
      @returnResult false, msg, callback

  allStocks: (restImpl) ->
    deferred = Q.defer()
    restImpl.GET "/inventory?limit=0", (error, response, body) =>
      if error
        deferred.reject "Error: " + error
      else if response.statusCode != 200
        deferred.reject "Problem: " + body
      else
        stocks = JSON.parse(body).results
        deferred.resolve stocks
    deferred.promise

  ensureChannel: (channelKey) ->
    deferred = Q.defer()
    @rest.GET "/channels?query=" + encodeURIComponent("key=\"#{channelKey}\""), (error, response, body) ->
      if error
        deferred.reject "Error: " + error
        return deferred.promise
      if response.statusCode == 200
        channels = JSON.parse(body).results
        if channels.length is 1
          deferred.resolve channels[0].id
          return deferred.promise
      # let's create the channel
      c =
        key: channelKey
      @rest.POST "/channels", JSON.stringify(c), (error, response, body) ->
        if error
          deferred.reject "Error: " + error
        else if response.statusCode == 201
          id = JSON.parse(body).id
          deferred.resolve id
        else
          deferred.reject "Problem: " + body
    deferred.promise

  initMatcher: () ->
    deferred = Q.defer()
    @allStocks(@rest).then (stocks) =>
      @existingStocks = stocks
      for es, i in @existingStocks
        @sku2index[es.sku] = i
      deferred.resolve true
    .fail (msg) ->
      deferred.reject msg
    deferred.promise

  match: (s) ->
    if @sku2index[s.sku] >= 0
      @existingStocks[@sku2index[s.sku]]

  update: (s, es, bar) ->
    deferred = Q.defer()
    @sync.buildActions(s, es).update (error, response, body) =>
      bar.tick()
      if error
        deferred.reject 'Error on updating stock.' + error
      else
        if response.statusCode is 200
          deferred.resolve 'Stock updated'
        else if response.statusCode is 304
          deferred.resolve 'Stock update not neccessary'
        else
          @deferred.reject 'Problem on updating existing stock.' + body
    deferred.promise

  create: (stock, bar) ->
    deferred = Q.defer()
    @rest.POST '/inventory', JSON.stringify(stock), (error, response, body) ->
      bar.tick()
      if error
        deferred.reject 'Error on creating new stock.' + error
      else
        if response.statusCode is 201
          deferred.resolve 'New stock created'
        else
          deferred.reject 'Problem on creating new stock.' + body
    deferred.promise

  mapStock: (xmljs, channelId) ->
    stocks = []
    for k,row of xmljs.row
      sku = xmlHelpers.xmlVal row, 'code'
      stocks.push @createEntry(sku, xmlHelpers.xmlVal(row, 'quantity'), xmlHelpers.xmlVal(row, 'CommittedDeliveryDate'))
      expectedQuantity = xmlHelpers.xmlVal row, 'AppointedQuantity'
      if expectedQuantity
        d = @createEntry(sku, expectedQuantity, xmlHelpers.xmlVal(row, 'deliverydate'), channelId)
        stocks.push d
    stocks

  createEntry: (sku, quantity, expectedDelivery, channelId) ->
    d =
      sku: sku
      quantityOnStock: parseInt(quantity)
    d.expectedDelivery = expectedDelivery if expectedDelivery
    if channelId
      d.supplyChannel =
        typeId: 'channel'
        id: channelId
    d

module.exports = StockXmlImport