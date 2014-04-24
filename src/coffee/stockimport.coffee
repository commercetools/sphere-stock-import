Q = require 'q'
_ = require 'underscore'
Csv = require 'csv'
{ElasticIo, Qutils} = require 'sphere-node-utils'
{InventorySync} = require 'sphere-node-sync'
SphereClient = require 'sphere-node-client'
package_json = require '../package.json'
xmlHelpers = require './xmlhelpers'

CHANNEL_KEY_FOR_XML_MAPPING = 'expectedStock'
CHANNEL_REF_NAME = 'supplyChannel'
CHANNEL_ROLES = ['InventorySupply', 'OrderExport', 'OrderImport']
LOG_PREFIX = "[SphereStockImport] "

class StockImport

  constructor: (@logger, options = {}) ->
    @sync = new InventorySync options
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
        .fail (err) ->
          ElasticIo.returnFailure err, next
        .done()

    else if _.size(msg.body) > 0
      _ensureChannel = =>
        if msg.body.CHANNEL_KEY?
          @client.channels.ensure(msg.body.CHANNEL_KEY, CHANNEL_ROLES)
          .then (result) =>
            @logger.debug result, 'Channel ensured, about to create or update'
            Q(result.body.id)
        else
          Q(msg.body.CHANNEL_ID)

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
      .fail (err) =>
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
      Q.reject "#{LOG_PREFIX}Unknown import mode '#{mode}'!"

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

    Q(message)

  performXML: (fileContent, next) ->
    deferred = Q.defer()
    xmlHelpers.xmlTransform xmlHelpers.xmlFix(fileContent), (err, xml) =>
      if err?
        deferred.reject "#{LOG_PREFIX}Error on parsing XML: #{err}"
      else
        @client.channels.ensure(CHANNEL_KEY_FOR_XML_MAPPING, CHANNEL_ROLES)
        .then (result) =>
          stocks = @_mapStockFromXML xml.root, result.body.id
          @_perform stocks, next
        .then (result) -> deferred.resolve result
        .fail (err) -> deferred.reject err
        .done()
    deferred.promise

  performCSV: (fileContent, next) ->
    deferred = Q.defer()
    Csv().from.string(fileContent, {delimiter: @csvDelimiter, trim: true})
    .to.array (data, count) =>
      headers = data[0]
      @_getHeaderIndexes headers, @csvHeaders
      .then (mappedHeaderIndexes) =>
        stocks = @_mapStockFromCSV _.tail(data), mappedHeaderIndexes[0], mappedHeaderIndexes[1]
        @logger.debug stocks, "Stock mapped from csv for headers #{mappedHeaderIndexes}"

        # TODO: ensure channel ??
        @_perform stocks, next
        .then (result) -> deferred.resolve result
      .fail (err) -> deferred.reject err
      .done()

    # TODO: register this before!
    .on 'error', (error) ->
      deferred.reject "#{LOG_PREFIX}Problem in parsing CSV: #{error}"
    deferred.promise

  _getHeaderIndexes: (headers, csvHeaders) ->
    Q.all _.map csvHeaders.split(','), (h) =>
      cleanHeader = h.trim()
      mappedHeader = _.find headers, (header) -> header.toLowerCase() is cleanHeader.toLowerCase()
      return Q.reject "Can't find header '#{cleanHeader}' in '#{headers}'." unless mappedHeader
      headerIndex = _.indexOf headers, mappedHeader
      @logger.debug headers, "Found index #{headerIndex} for header #{cleanHeader}"
      Q(headerIndex)

  _mapStockFromXML: (xmljs, channelId) ->
    stocks = []
    if xmljs.row?
      _.each xmljs.row, (row) =>
        sku = xmlHelpers.xmlVal row, 'code'
        stocks.push @_createInventoryEntry(sku, xmlHelpers.xmlVal(row, 'quantity'))
        appointedQuantity = xmlHelpers.xmlVal row, 'AppointedQuantity'
        if appointedQuantity?
          expectedDelivery = xmlHelpers.xmlVal row, 'CommittedDeliveryDate'
          if expectedDelivery?
            expectedDelivery = new Date(expectedDelivery).toISOString()
          d = @_createInventoryEntry(sku, appointedQuantity, expectedDelivery, channelId)
          stocks.push d
    stocks

  _mapStockFromCSV: (rows, skuIndex = 0, quantityIndex = 1) ->
    _.map rows, (row) =>
      sku = row[skuIndex].trim()
      quantity = row[quantityIndex].trim()
      @_createInventoryEntry sku, quantity

  _createInventoryEntry: (sku, quantity, expectedDelivery, channelId) ->
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
      Q "#{LOG_PREFIX}elastic.io messages sent."
    else
      Qutils.processList stocks, (stocksToProcess) =>
        ie = @client.inventoryEntries.perPage(0).whereOperator('or')
        @logger.debug stocksToProcess, 'Stocks to process'
        _.each stocksToProcess, (s) =>
          @summary.emptySKU++ if _.isEmpty s.sku
          # TODO: query also for channel?
          ie.where("sku = \"#{s.sku}\"")
        ie.fetch()
        .then (results) =>
          @logger.debug results, 'Fetched stocks'
          queriedEntries = results.body.results
          @_createOrUpdate stocksToProcess, queriedEntries
        .then (results) =>
          _.each results, (r) =>
            switch r.statusCode
              when 201 then @summary.created++
              when 200 then @summary.updated++
          Q()
      , {maxParallel: 50, accumulate: false}

  _match: (entry, existingEntries) ->
    _.find existingEntries, (existingEntry) ->
      if existingEntry.sku is entry.sku
        if _.has(existingEntry, CHANNEL_REF_NAME) and _.has(entry, CHANNEL_REF_NAME)
          existingEntry[CHANNEL_REF_NAME].id is entry[CHANNEL_REF_NAME].id
        else
          not _.has(entry, CHANNEL_REF_NAME)

  _createOrUpdate: (inventoryEntries, existingEntries) ->
    @logger.debug inventoryEntries, 'Inventory entries'
    posts = _.map inventoryEntries, (entry) =>
      existingEntry = @_match(entry, existingEntries)
      if existingEntry?
        @sync.buildActions(entry, existingEntry).update()
      else
        @client.inventoryEntries.create(entry)

    @logger.debug "About to send #{_.size posts} requests"
    Q.all(posts)

module.exports = StockImport
