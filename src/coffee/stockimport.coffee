debug = require('debug')('sphere-stock-import')
_ = require 'underscore'
csv = require 'csv'
Promise = require 'bluebird'
{ElasticIo} = require 'sphere-node-utils'
{SphereClient, InventorySync} = require 'sphere-node-sdk'
package_json = require '../package.json'
CONS = require './constants'
CustomFieldMappings = require './mappings'
xmlHelpers = require './xmlhelpers'

class StockImport

  constructor: (@logger, options = {}) ->
    options = _.defaults options, {user_agent: 'sphere-stock-import', max409Retries: 10}
    @sync = new InventorySync
    @client = new SphereClient options
    @csvHeaders = options.csvHeaders
    @csvDelimiter = options.csvDelimiter
    @customFieldMappings = new CustomFieldMappings()
    @max409Retries = options.max409Retries
    @_resetSummary()

  _resetSummary: ->
    @_summary =
      emptySKU: 0
      created: 0
      updated: 0

  getMode: (fileName) ->
    switch
      when fileName.match /\.csv$/i then 'CSV'
      when fileName.match /\.xml$/i then 'XML'
      else throw new Error "Unsupported mode (file extension) for file #{fileName} (use csv or xml)"

  _escapeSku: (sku) ->
    JSON.stringify(sku)

  ###
  Elastic.io calls this for each csv row, so each inventory entry will be processed at a time
  ###
  elasticio: (msg, cfg, next, snapshot) ->
    debug 'Running elastic.io: %j', msg
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
          @client.channels.ensure(msg.body.CHANNEL_KEY, CONS.CHANNEL_ROLES)
          .then (result) ->
            debug 'Channel ensured, about to create or update: %j', result
            Promise.resolve(result.body.id)
        else
          Promise.resolve(msg.body.CHANNEL_ID)

      @client.inventoryEntries.where("sku=#{@_escapeSku(msg.body.SKU)}").perPage(1).fetch()
      .then (results) =>
        debug 'Existing entries: %j', results
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
              when 201 then @_summary.created++
              when 200 then @_summary.updated++
          @summaryReport()
        .then (message) ->
          ElasticIo.returnSuccess message, next
      .catch (err) ->
        debug 'Failed to process inventory: %j', err
        ElasticIo.returnFailure err, next
      .done()
    else
      ElasticIo.returnFailure "#{CONS.LOG_PREFIX}No data found in elastic.io msg.", next

  run: (fileContent, mode, next) ->
    @_resetSummary()
    if mode is 'XML'
      @performXML fileContent, next
    else if mode is 'CSV'
      @performCSV fileContent, next
    else
      Promise.reject "#{CONS.LOG_PREFIX}Unknown import mode '#{mode}'!"

  summaryReport: (filename) ->
    if @_summary.created is 0 and @_summary.updated is 0
      message = 'Summary: nothing to do, everything is fine'
    else
      message = "Summary: there were #{@_summary.created + @_summary.updated} imported stocks " +
        "(#{@_summary.created} were new and #{@_summary.updated} were updates)"

    if @_summary.emptySKU > 0
      message += "\nFound #{@_summary.emptySKU} empty SKUs from file input"
      message += " '#{filename}'" if filename

    message

  performXML: (fileContent, next) ->
    new Promise (resolve, reject) =>
      xmlHelpers.xmlTransform xmlHelpers.xmlFix(fileContent), (err, xml) =>
        if err?
          reject "#{CONS.LOG_PREFIX}Error on parsing XML: #{err}"
        else
          @client.channels.ensure(CONS.CHANNEL_KEY_FOR_XML_MAPPING, CONS.CHANNEL_ROLES)
          .then (result) =>
            stocks = @_mapStockFromXML xml.root, result.body.id
            @_perform stocks, next
          .then (result) -> resolve result
          .catch (err) -> reject err
          .done()

  performCSV: (fileContent, next) ->
    new Promise (resolve, reject) =>
      csv.parse fileContent, {delimiter: @csvDelimiter, trim: true}, (error, data) =>
        if (error)
          reject "#{CONS.LOG_PREFIX}Problem in parsing CSV: #{error}"

        headers = data[0]
        @_mapStockFromCSV(_.rest(data), headers).then (stocks) =>
          debug "Stock mapped from csv for headers #{headers}: %j", stocks

          @_perform stocks, next
            .then (result) -> resolve result
        .catch (err) -> reject err
        .done()

  performStream: (chunk, cb) ->
    @_processBatches(chunk).then -> cb()

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

  _mapStockFromCSV: (rows, mappedHeaderIndexes) ->
    return new Promise (resolve, reject) =>
      rowIndex = 0 # very weird that csv does not support this internally
      csv.transform(rows,(row, cb) =>
        rowIndex++
        _data = {}

        Promise.each(row, (cell, index) =>
          headerName = mappedHeaderIndexes[index]

          # Change deprecated header 'quantity' to 'quantityOnStock' for backward compatibility
          if headerName == CONS.DEPRECATED_HEADER_QUANTITY
            @logger.warn "The header name #{CONS.DEPRECATED_HEADER_QUANTITY} has been deprecated!"
            @logger.warn "Please change #{CONS.DEPRECATED_HEADER_QUANTITY} to #{CONS.HEADER_QUANTITY}"
            headerName = CONS.HEADER_QUANTITY

          if CONS.HEADER_CUSTOM_REGEX.test headerName
            customTypeKey = row[mappedHeaderIndexes.indexOf(CONS.HEADER_CUSTOM_TYPE)]

            @_getCustomTypeDefinition(customTypeKey).then (response) =>
              customTypeDefinition = response.body
              @_mapCustomField(_data, cell, headerName, customTypeDefinition, rowIndex)

          else
            Promise.resolve(@_mapCellData(cell, headerName)).then (cellData) ->
              _data[headerName] = cellData

        ).then =>
          if _.size(@customFieldMappings.errors) isnt 0
            return cb @customFieldMappings.errors
          cb null, _data
      , (err, data) ->
        if err
          reject(err)
        else
          resolve(data)
      )


  _mapCellData: (data, headerName) ->
    data = data?.trim()
    switch on
      when CONS.HEADER_QUANTITY is headerName then parseInt(data, 10) or 0
      when CONS.HEADER_RESTOCKABLE is headerName then parseInt(data, 10)
      when CONS.HEADER_SUPPLY_CHANNEL is headerName then @_mapChannelKeyToReference data
      else data

  _mapCustomField: (data, cell, headerName, customTypeDefinition, rowIndex) ->
    fieldName = headerName.split(CONS.HEADER_CUSTOM_SEPERATOR)[1]
    lang = headerName.split(CONS.HEADER_CUSTOM_SEPERATOR)[2]

    # set data.custom once per row with the type defined
    if !data.custom
      data.custom = {
        "type": {
          "id": customTypeDefinition.id
        },
        "fields": {}
      }
    # Set localized object if present
    if lang
      data.custom.fields[fieldName] =
        _.defaults (data.custom.fields[fieldName] || {}),
        @customFieldMappings.mapFieldTypes({
          fieldDefinitions: customTypeDefinition.fieldDefinitions,
          typeDefinitionKey: customTypeDefinition.key,
          rowIndex: rowIndex,
          key: fieldName,
          value: cell,
          langHeader: lang,
        })
    else
      data.custom.fields[fieldName] = @customFieldMappings.mapFieldTypes({
        fieldDefinitions: customTypeDefinition.fieldDefinitions,
        typeDefinitionKey: customTypeDefinition.key,
        rowIndex: rowIndex,
        key: fieldName,
        value: cell,
      })

  # Memoize to prevent unneeded API calls
  _getCustomTypeDefinition: _.memoize (customTypeKey) ->
    @client.types.byKey(customTypeKey).fetch()

  # Memoize to prevent unneeded API calls
  _mapChannelKeyToReference: _.memoize (key) ->
    @client.channels.where("key=\"#{key}\"").fetch()
    .then (response) =>
      if (response.body.results[0] && response.body.results[0].id)
        return typeId: CONS.CHANNEL_REFERENCE_TYPE, id: response.body.results[0].id

        @customFieldMappings.errors.push("Couldn\'t find channel with #{key} as key.")
        .catch (@customFieldMappings.errors.push)

  _createInventoryEntry: (sku, quantity, expectedDelivery, channelId) ->
    entry =
      sku: sku
      quantityOnStock: parseInt(quantity, 10) or 0 # avoid NaN
    entry.expectedDelivery = expectedDelivery if expectedDelivery?
    if channelId?
      entry[CONS.CHANNEL_REF_NAME] =
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
        if entry[CONS.CHANNEL_REF_NAME]?
          msg.body.CHANNEL_ID = entry[CONS.CHANNEL_REF_NAME].id
        ElasticIo.returnSuccess msg, next
      Promise.resolve "#{CONS.LOG_PREFIX}elastic.io messages sent."
    else
      @_processBatches(stocks)

  _processBatches: (stocks) ->
    batchedList = stocks.reduce (batch, value, index) ->
      if index % 30 == 0 then batch.push []

      batch[batch.length - 1].push value
      batch
    , []

    Promise.map batchedList, (stocksToProcess) =>
      debug 'Chunk: %j', stocksToProcess
      uniqueStocksToProcessBySku = @_uniqueStocksBySku(stocksToProcess)
      debug 'Chunk (unique stocks): %j', uniqueStocksToProcessBySku

      skus = _.map uniqueStocksToProcessBySku, (s) =>
        @_summary.emptySKU++ if _.isEmpty s.sku
        # TODO: query also for channel?
        "#{@_escapeSku(s.sku)}"
      predicate = "sku in (#{skus.join(', ')})"

      @client.inventoryEntries.all()
      .perPage(500)
      .where(predicate)
      .fetch()
      .then (results) =>
        debug 'Fetched stocks: %j', results
        queriedEntries = results.body.results
        @_createOrUpdate stocksToProcess, queriedEntries
      .then (results) =>
        _.each results, (r) =>
          switch r.statusCode
            when 201 then @_summary.created++
            when 200 then @_summary.updated++
        Promise.resolve()
    , {concurrency: 1} # run 1 batch at a time

  _uniqueStocksBySku: (stocks) ->
    _.reduce stocks, (acc, stock) ->
      foundStock = _.find acc, (s) -> s.sku is stock.sku
      acc.push stock unless foundStock
      acc
    , []

  _match: (entry, existingEntries) ->
    _.find existingEntries, (existingEntry) ->
      if entry.sku is existingEntry.sku
        # check channel
        # - if they have the same channel, it's the same entry
        # - if they have different channels or one of them has no channel, it's not
        if _.has(entry, CONS.CHANNEL_REF_NAME) and _.has(existingEntry, CONS.CHANNEL_REF_NAME)
          entry[CONS.CHANNEL_REF_NAME].id is existingEntry[CONS.CHANNEL_REF_NAME].id
        else
          if _.has(entry, CONS.CHANNEL_REF_NAME) or _.has(existingEntry, CONS.CHANNEL_REF_NAME)
            false # one of them has a channel, the other not
          else
            true # no channel, but same sku
      else
        false

  _createOrUpdate: (inventoryEntries, existingEntries) ->
    debug 'Inventory entries: %j', {toProcess: inventoryEntries, existing: existingEntries}

    posts = _.map inventoryEntries, (entry) =>
      existingEntry = @_match(entry, existingEntries)
      if existingEntry?
        @_updateInventory(entry, existingEntry)
      else
        @client.inventoryEntries.create(entry)

    debug 'About to send %s requests', _.size(posts)
    Promise.all(posts)

  _updateInventory: (entry, existingEntry, tryCount = 1) =>
    synced = @sync.buildActions(entry, existingEntry)
    if synced.shouldUpdate()
      @client.inventoryEntries.byId(synced.getUpdateId()).update(synced.getUpdatePayload())
      .catch (err) =>
        if (err.statusCode == 409)
          debug "Got 409 error for entry #{JSON.stringify(entry)}, repeat the request "
          + "for #{tryCount} times."
          if (tryCount <= @max409Retries)
            @client.inventoryEntries
            .byId(synced.getUpdateId())
            .fetch()
            .then (result) =>
              @_updateInventory(entry, result.body, tryCount + 1)
            .catch (err) =>
              if (err.statusCode == 404)
                debug "It seems that stock update has conflicted with parallel stock deletion "
                + "and can no longer be updated. A new stock will be created instead."
                @client.inventoryEntries.create(entry)
              else
                debug "Error on handling 409 stock update error. Details: #{JSON.stringify(err)}"
                Promise.reject err
          else
            debug "Failed to retry the task after #{@max409Retries} attempts for stock #{JSON.stringify(entry)}"
            Promise.reject err
        else if (err.statusCode == 404)
          debug "It seems that stock update has conflicted with parallel stock deletion "
          + "and can no longer be updated. A new stock will be created instead."
          @client.inventoryEntries.create(entry)
        else
          Promise.reject err
    else
      Promise.resolve statusCode: 304

module.exports = StockImport
