_ = require 'underscore'
Csv = require 'csv'
SphereClient = require 'sphere-node-client'
{ElasticIo} = require 'sphere-node-utils'
{InventorySync} = require 'sphere-node-sync'
package_json = require '../package.json'
xmlHelpers = require './xmlhelpers'
Q = require 'q'

CHANNEL_KEY_FOR_XML_MAPPING = 'expectedStock'
CHANNEL_REF_NAME = 'supplyChannel'
CHANNEL_ROLES = ['InventorySupply', 'OrderExport', 'OrderImport']
LOG_PREFIX = "[SphereStockImport] "

class StockImport

  _log: (msg) ->
    if @client?
      client._logger.info msg
    console.log "#{LOG_PREFIX}#{msg}"

  constructor: (options) ->
    if options?
      @client = new SphereClient options
      @sync = new InventorySync options
      @existingInventoryEntries = {}

  getMode: (fileName) ->
    switch
      when fileName.match /\.csv$/i then 'CSV'
      when fileName.match /\.xml$/i then 'XML'

  elasticio: (msg, cfg, next, snapshot) ->
    if _.size(msg.attachments) > 0
      for attachment of msg.attachments
        content = msg.attachments[attachment].content
        continue unless content
        encoded = new Buffer(content, 'base64').toString()
        mode = @getMode attachment
        @run encoded, mode, next
        .then (result) =>
          ElasticIo.returnSuccess @sumResult(result), next
        .fail (err) ->
          ElasticIo.returnFailure err, next
        .done()

    else if _.size(msg.body) > 0
      @_initMatcher("sku=\"#{msg.body.SKU}\"")
      .then =>
        if msg.body.CHANNEL_KEY?
          @ensureChannelByKey(@client._rest, msg.body.CHANNEL_KEY, CHANNEL_ROLES)
          .then (result) =>
            @_createOrUpdate([@createInventoryEntry(msg.body.SKU, msg.body.QUANTITY, msg.body.EXPECTED_DELIVERY, result.id)])
          .then (result) =>
            ElasticIo.returnSuccess @sumResult(result), next
        else
          @_createOrUpdate([@createInventoryEntry(msg.body.SKU, msg.body.QUANTITY, msg.body.EXPECTED_DELIVERY, msg.body.CHANNEL_ID)])
          .then (result) =>
            ElasticIo.returnSuccess @sumResult(result), next
      .fail (msg) ->
        ElasticIo.returnFailure err, next
      .done()
    else
      ElasticIo.returnFailure "#{LOG_PREFIX}No data found in elastic.io msg.", next

  ensureChannelByKey: (rest, channelKey, channelRolesForCreation) ->
    deferred = Q.defer()
    query = encodeURIComponent("key=\"#{channelKey}\"")
    rest.GET "/channels?where=#{query}", (error, response, body) ->
      if error?
        deferred.reject "Error on getting channel: #{error}"
      else if response.statusCode isnt 200
        humanReadable = JSON.stringify body, null, 2
        deferred.reject "#{LOG_PREFIX}Problem on getting channel: #{humanReadable}"
      else
        channels = body.results
        if _.size(channels) is 1
          deferred.resolve channels[0]
        else
          channel =
            key: channelKey
            roles: channelRolesForCreation
          rest.POST '/channels', channel, (error, response, body) ->
            if error?
              deferred.reject "#{LOG_PREFIX}Error on creating channel: #{error}"
            else if response.statusCode is 201
              deferred.resolve body
            else
              humanReadable = JSON.stringify body, null, 2
              deferred.reject "#{LOG_PREFIX}Problem on creating channel: #{humanReadable}"

    deferred.promise

  run: (fileContent, mode, next) ->
    if mode is 'XML'
      @performXML fileContent, next
    else if mode is 'CSV'
      @performCSV fileContent, next
    else
      Q.reject "#{LOG_PREFIX}Unknown import mode '#{mode}'!"

  sumResult: (result) ->
    if _.isArray result
      if _.isEmpty result
        'Nothing done.'
      else
        nums = _.reduce result, ((memo, r) ->
          switch r.statusCode
            when 201 then memo[0] = memo[0] + 1
            when 200 then memo[1] = memo[1] + 1
            when 304 then memo[2] = memo[2] + 1
          memo
          ), [0, 0, 0]
        res =
          'Inventory entry created.': nums[0]
          'Inventory entry updated.': nums[1]
          'Inventory update was not necessary.': nums[2]
    else
      result

  performCSV: (fileContent, next) ->
    deferred = Q.defer()

    Csv().from.string(fileContent)
    .to.array (data, count) =>
      header = data[0]
      stocks = @_mapStockFromCSV _.rest data
      @_perform stocks, next
      .then (result) ->
        deferred.resolve result
      .fail (err) ->
        deferred.reject err
      .done()

    # TODO: register this before!
    .on 'error', (error) ->
      deferred.reject "#{LOG_PREFIX}Problem in parsing CSV: #{error}"

    deferred.promise

  _mapStockFromCSV: (rows, skuIndex = 0, quantityIndex = 1) ->
    _.map rows, (row) =>
      sku = row[skuIndex]
      quantity = row[quantityIndex]
      @createInventoryEntry sku, quantity

  performXML: (fileContent, next) ->
    deferred = Q.defer()
    xmlHelpers.xmlTransform xmlHelpers.xmlFix(fileContent), (err, xml) =>
      if err?
        deferred.reject "#{LOG_PREFIX}Error on parsing XML: #{err}"
      else
        @ensureChannelByKey(@client._rest, CHANNEL_KEY_FOR_XML_MAPPING, CHANNEL_ROLES)
        .then (result) =>
          stocks = @_mapStockFromXML xml.root, result.id
          @_perform stocks, next
          .then (result) ->
            deferred.resolve result
        .fail (err) ->
          deferred.reject err
        .done()

    deferred.promise

  _mapStockFromXML: (xmljs, channelId) ->
    stocks = []
    if xmljs.row?
      _.each xmljs.row, (row) =>
        sku = xmlHelpers.xmlVal row, 'code'
        stocks.push @createInventoryEntry(sku, xmlHelpers.xmlVal(row, 'quantity'))
        appointedQuantity = xmlHelpers.xmlVal row, 'AppointedQuantity'
        if appointedQuantity?
          expectedDelivery = xmlHelpers.xmlVal row, 'CommittedDeliveryDate'
          if expectedDelivery?
            expectedDelivery = new Date(expectedDelivery).toISOString()
          d = @createInventoryEntry(sku, appointedQuantity, expectedDelivery, channelId)
          stocks.push d

    stocks

  createInventoryEntry: (sku, quantity, expectedDelivery, channelId) ->
    entry =
      sku: sku
      quantityOnStock: parseInt(quantity)
    entry.expectedDelivery = expectedDelivery if expectedDelivery?
    if channelId?
      entry[CHANNEL_REF_NAME] =
        typeId: 'channel'
        id: channelId

    entry

  _perform: (stocks, next) ->
    @_log "Stock entries to process: #{_.size(stocks)}"
    if _.isFunction next
      _.each stocks, (entry) ->
        msg =
          body:
            SKU: entry.sku
            QUANTITY: entry.quantityOnStock
        if entry.expectedDelivery?
          msg.body.EXPECTED_DELIVERY = entry.expectedDelivery
        if entry[CHANNEL_REF_NAME]?
          msg.body.CHANNEL_ID = entry[CHANNEL_REF_NAME].id
        ElasticIo.returnSuccess msg, next
      Q "#{LOG_PREFIX}elastic.io messages sent."
    else
      @_initMatcher().then =>
        @_createOrUpdate stocks

  _initMatcher: (where) ->
    req = @client.inventoryEntries
    if where?
      req = req.where(where).perPage(1)
    else
      req = req.perPage(0)
    req.fetch()
    .then (result) =>
      @existingInventoryEntries = result.body.results
      @_log "Existing entries: #{_.size @existingInventoryEntries}"
      Q '#{LOG_PREFIX}matcher initialized'

  _match: (entry) ->
    _.find @existingInventoryEntries, (existingEntry) ->
      if existingEntry.sku is entry.sku
        if _.has(existingEntry, CHANNEL_REF_NAME) and _.has(entry, CHANNEL_REF_NAME)
          existingEntry[CHANNEL_REF_NAME].id is entry[CHANNEL_REF_NAME].id
        else
          not _.has(entry, CHANNEL_REF_NAME)

  _createOrUpdate: (inventoryEntries) ->
    posts = _.map inventoryEntries, (entry) =>
      existingEntry = @_match(entry)
      if existingEntry?
        @sync.buildActions(entry, existingEntry).update()
      else
        @client.inventoryEntries.create(entry)

    @_log "Requests: #{_.size posts}"
    Q.all(posts)

module.exports = StockImport
