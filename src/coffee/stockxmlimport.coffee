_ = require('underscore')._
xmlHelpers = require '../lib/xmlhelpers'
package_json = require '../package.json'
InventoryUpdater = require('sphere-node-sync').InventoryUpdater
Q = require 'q'

class StockXmlImport extends InventoryUpdater

  CHANNEL_KEY = 'expectedStock'

  constructor: (options) ->
    options.user_agent = "#{package_json.name} - #{package_json.version}" unless _.isEmpty options
    super(options)

  elasticio: (msg, cfg, cb, snapshot) ->
    if _.size(msg.attachments) > 0
      for attachment of msg.attachments
        continue if not attachment.match /xml$/i
        content = msg.attachments[attachment].content
        continue if not content
        xmlString = new Buffer(content, 'base64').toString()
        @run xmlString, cb
    else if _.size(msg.body) > 0
      # TODO: As we get only one entry here, we should query for the existing one and not
      # get the whole inventory
      @initMatcher().then () =>
        if msg.body.CHANNEL_KEY
          @ensureChannelByKey(@rest, msg.body.CHANNEL_KEY).then (channel) =>
            @createOrUpdate([@createInventoryEntry(msg.body.SKU, msg.body.QUANTITY, msg.body.EXPECTED_DELIVERY, channel.id)], cb)
        else
          @createOrUpdate([@createInventoryEntry(msg.body.SKU, msg.body.QUANTITY, msg.body.EXPECTED_DELIVERY, msg.body.CHANNEL_ID)], cb)
      .fail (msg) =>
        @returnResult false, msg, cb
    else
      @returnResult false, 'No data found in elastic.io msg.', cb

  run: (xmlString, callback) ->
    throw new Error 'String required' unless _.isString xmlString
    throw new Error 'Callback must be a function' unless _.isFunction callback

    xmlHelpers.xmlTransform xmlHelpers.xmlFix(xmlString), (err, result) =>
      if err
        @returnResult false, 'Error on parsing XML: ' + err, callback
      else
        @ensureChannelByKey(@rest, CHANNEL_KEY).then (channel) =>
          stocks = @mapStock result.root, channel.id
          console.log "stock entries to process: ", _.size(stocks)
          @initMatcher().then (result) =>
            @createOrUpdate stocks, callback
          .fail (msg) =>
            @returnResult false, msg, callback
        .fail (msg) =>
          @returnResult false, msg, callback

  mapStock: (xmljs, channelId) ->
    stocks = []
    return stocks unless xmljs.row
    for row in xmljs.row
      sku = xmlHelpers.xmlVal row, 'code'
      stocks.push @createInventoryEntry(sku, xmlHelpers.xmlVal(row, 'quantity'))
      appointedQuantity = xmlHelpers.xmlVal row, 'AppointedQuantity'
      if appointedQuantity
        expectedDelivery = xmlHelpers.xmlVal(row, 'CommittedDeliveryDate', xmlHelpers.xmlVal(row, 'deliverydate'))
        date = new Date expectedDelivery
        d = @createInventoryEntry(sku, appointedQuantity, date.toISOString(), channelId)
        stocks.push d
    stocks

module.exports = StockXmlImport
