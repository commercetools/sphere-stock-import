_ = require 'underscore'
_.mixin require('underscore-mixins')
Csv = require 'csv'
Promise = require 'bluebird'
{ElasticIo} = require 'sphere-node-utils'
{SphereClient, InventorySync} = require 'sphere-node-sdk'
package_json = require '../package.json'
xmlHelpers = require './xmlhelpers'

CHANNEL_KEY_FOR_XML_MAPPING = 'expectedStock'
CHANNEL_REF_NAME = 'supplyChannel'
CHANNEL_ROLES = ['InventorySupply', 'OrderExport', 'OrderImport']
LOG_PREFIX = "[SphereStockImport] "

class StockImport

  constructor: (@logger, options = {}) ->
    @sync = new InventorySync
    @client = new SphereClient options
    @csvHeaders = options.csvHeaders
    @csvDelimiter = options.csvDelimiter
    @_resetSummary()

  _resetSummary: ->
    @summary =
      emptySKU: 0
      created: 0
      updated: 0

  getMode: (fileName) ->
    switch
      when fileName.match /\.csv$/i then 'CSV'
      when fileName.match /\.xml$/i then 'XML'
      else throw new Error "Unsupported mode (file extension) for file #{fileName} (use csv or xml)"

  ###
  Elastic.io calls this for each csv row, so each inventory entry will be processed at a time
  ###
  elasticio: (msg, cfg, next, snapshot) ->
    @logger.debug msg, 'Running elastic.io'
    if _.size(msg.attachments) > 0
      for attachment of msg.attachments
        content = msg.attachments[attachment].content
        continue unless content
        encoded = new Buffer(content, 'base64').toString()
        mode = @getMode attachment
        @run encoded, mode, next
        .then (result) =>
          if result
            ElasticIo.returnSuccess result, next
          else
            @summaryReport()
            .then (message) ->
              ElasticIo.returnSuccess message, next
        .catch (err) ->
          ElasticIo.returnFailure err, next
        .done()

    else if _.size(msg.body) > 0
      _ensureChannel = =>
        if msg.body.CHANNEL_KEY?
          @client.channels.ensure(msg.body.CHANNEL_KEY, CHANNEL_ROLES)
          .then (result) =>
            @logger.debug result, 'Channel ensured, about to create or update'
            Promise.resolve(result.body.id)
        else
          Promise.resolve(msg.body.CHANNEL_ID)

      @client.inventoryEntries.where("sku=\"#{msg.body.SKU}\"").perPage(1).fetch()
      .then (results) =>
        @logger.debug results, 'Existing entries'
        existingEntries = results.body.results
        _ensureChannel()
        .then (channelId) =>
          stocksToProcess = [
            @_createInventoryEntry(msg.body.SKU, msg.body.QUANTITY, msg.body.EXPECTED_DELIVERY, channelId)
          ]
          @_createOrUpdate stocksToProcess, existingEntries
        .then (results) =>
          _.each results, (r) =>
            switch r.statusCode
              when 201 then @summary.created++
              when 200 then @summary.updated++
          @summaryReport()
        .then (message) ->
          ElasticIo.returnSuccess message, next
      .catch (err) =>
        @logger.debug err, 'Failed to process inventory'
        ElasticIo.returnFailure err, next
      .done()
    else
      ElasticIo.returnFailure "#{LOG_PREFIX}No data found in elastic.io msg.", next

  run: (fileContent, mode, next) ->
    @_resetSummary()
    if mode is 'XML'
      @performXML fileContent, next
    else if mode is 'CSV'
      @performCSV fileContent, next
    else
      Promise.reject "#{LOG_PREFIX}Unknown import mode '#{mode}'!"

  summaryReport: (filename) ->
    if @summary.created is 0 and @summary.updated is 0
      message = 'Summary: nothing to do, everything is fine'
    else
      message = "Summary: there were #{@summary.created + @summary.updated} imported stocks " +
        "(#{@summary.created} were new and #{@summary.updated} were updates)"

    if @summary.emptySKU > 0
      warning = "Found #{@summary.emptySKU} empty SKUs from file input"
      warning += " '#{filename}'" if filename
      @logger.warn warning

    Promise.resolve(message)

  performXML: (fileContent, next) ->
    new Promise (resolve, reject) =>
      xmlHelpers.xmlTransform xmlHelpers.xmlFix(fileContent), (err, xml) =>
        if err?
          reject "#{LOG_PREFIX}Error on parsing XML: #{err}"
        else
          @client.channels.ensure(CHANNEL_KEY_FOR_XML_MAPPING, CHANNEL_ROLES)
          .then (result) =>
            stocks = @_mapStockFromXML xml.root, result.body.id
            @_perform stocks, next
          .then (result) -> resolve result
          .catch (err) -> reject err
          .done()

  performCSV: (fileContent, next) ->
    new Promise (resolve, reject) =>
      Csv().from.string(fileContent, {delimiter: @csvDelimiter, trim: true})
      .to.array (data, count) =>
        headers = data[0]
        @_getHeaderIndexes headers, @csvHeaders
        .then (mappedHeaderIndexes) =>
          stocks = @_mapStockFromCSV _.tail(data), mappedHeaderIndexes[0], mappedHeaderIndexes[1]
          @logger.debug stocks, "Stock mapped from csv for headers #{mappedHeaderIndexes}"

          # TODO: ensure channel ??
          @_perform stocks, next
          .then (result) -> resolve result
        .catch (err) -> reject err
        .done()
      .on 'error', (error) ->
        reject "#{LOG_PREFIX}Problem in parsing CSV: #{error}"

  performStream: (chunk, cb) ->
    _processBatches(chunk).then -> cb()

  _getHeaderIndexes: (headers, csvHeaders) ->
    Promise.all _.map csvHeaders.split(','), (h) =>
      cleanHeader = h.trim()
      mappedHeader = _.find headers, (header) -> header.toLowerCase() is cleanHeader.toLowerCase()
      if mappedHeader
        headerIndex = _.indexOf headers, mappedHeader
        @logger.debug headers, "Found index #{headerIndex} for header #{cleanHeader}"
        Promise.resolve(headerIndex)
      else
        Promise.reject "Can't find header '#{cleanHeader}' in '#{headers}'."

  _mapStockFromXML: (xmljs, channelId) ->
    stocks = []
    if xmljs.row?
      _.each xmljs.row, (row) =>
        sku = xmlHelpers.xmlVal row, 'code'
        stocks.push @_createInventoryEntry(sku, xmlHelpers.xmlVal(row, 'quantity'))
        appointedQuantity = xmlHelpers.xmlVal row, 'appointedquantity'
        if appointedQuantity?
          expectedDelivery = undefined
          committedDeliveryDate = xmlHelpers.xmlVal row, 'committeddeliverydate'
          if committedDeliveryDate
            try
              expectedDelivery = new Date(committedDeliveryDate).toISOString()
            catch error
              @logger.warn "Can't parse date '#{committedDeliveryDate}'. Creating entry without date..."
          d = @_createInventoryEntry(sku, appointedQuantity, expectedDelivery, channelId)
          stocks.push d
    stocks

  _mapStockFromCSV: (rows, skuIndex = 0, quantityIndex = 1) ->
    _.map rows, (row) =>
      sku = row[skuIndex].trim()
      quantity = row[quantityIndex]?.trim()
      @_createInventoryEntry sku, quantity

  _createInventoryEntry: (sku, quantity, expectedDelivery, channelId) ->
    entry =
      sku: sku
      quantityOnStock: parseInt(quantity, 10) or 0 # avoid NaN
    entry.expectedDelivery = expectedDelivery if expectedDelivery?
    if channelId?
      entry[CHANNEL_REF_NAME] =
        typeId: 'channel'
        id: channelId
    entry

  _perform: (stocks, next) ->
    @logger.info "Stock entries to process: #{_.size(stocks)}"
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
      Promise.resolve "#{LOG_PREFIX}elastic.io messages sent."
    else
      @_processBatches(stocks)

  _processBatches: (stocks) ->
    batchedList = _.batchList(stocks, 30) # max parallel elem to process
    Promise.map batchedList, (stocksToProcess) =>
      ie = @client.inventoryEntries.all().whereOperator('or')
      @logger.debug stocksToProcess, 'Stocks to process'
      uniqueStocksToProcessBySku = _.reduce stocksToProcess, (acc, stock) ->
        foundStock = _.find acc, (s) -> s.sku is stock.sku
        acc.push stock unless foundStock
        acc
      , []
      _.each uniqueStocksToProcessBySku, (s) =>
        @summary.emptySKU++ if _.isEmpty s.sku
        # TODO: query also for channel?
        ie.where("sku = \"#{s.sku}\"")
      ie.sort('sku').fetch()
      .then (results) =>
        @logger.debug results, 'Fetched stocks'
        queriedEntries = results.body.results
        @_createOrUpdate stocksToProcess, queriedEntries
      .then (results) =>
        _.each results, (r) =>
          switch r.statusCode
            when 201 then @summary.created++
            when 200 then @summary.updated++
        Promise.resolve()
    , {concurrency: 1} # run 1 batch at a time

  _match: (entry, existingEntries) ->
    _.find existingEntries, (existingEntry) ->
      if entry.sku is existingEntry.sku
        # check channel
        # - if they have the same channel, it's the same entry
        # - if they have different channels or one of them has no channel, it's not
        if _.has(entry, CHANNEL_REF_NAME) and _.has(existingEntry, CHANNEL_REF_NAME)
          entry[CHANNEL_REF_NAME].id is existingEntry[CHANNEL_REF_NAME].id
        else
          if _.has(entry, CHANNEL_REF_NAME) or _.has(existingEntry, CHANNEL_REF_NAME)
            false # one of them has a channel, the other not
          else
            true # no channel, but same sku
      else
        false

  _createOrUpdate: (inventoryEntries, existingEntries) ->
    @logger.debug {toProcess: inventoryEntries, existing: existingEntries}, 'Inventory entries'

    posts = _.map inventoryEntries, (entry) =>
      existingEntry = @_match(entry, existingEntries)
      if existingEntry?
        synced = @sync.buildActions(entry, existingEntry)
        if synced.shouldUpdate()
          @client.inventoryEntries.byId(synced.getUpdateId()).update(synced.getUpdatePayload())
        else
          Promise.resolve statusCode: 304
      else
        @client.inventoryEntries.create(entry)

    @logger.debug "About to send #{_.size posts} requests"
    Promise.all(posts)

module.exports = StockImport
