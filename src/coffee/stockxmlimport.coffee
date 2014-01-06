_ = require('underscore')._
xmlHelpers = require '../lib/xmlhelpers'
InventoryUpdater = require('sphere-node-sync').InventoryUpdater
Q = require 'q'

class StockXmlImport extends InventoryUpdater
  constructor: (options) ->
    super(options)

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
        @createOrUpdate([@createInventoryEntry(msg.body.SKU, msg.body.QUANTITY)], cb)
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
        @ensureChannelByKey(@rest, 'expectedStock').then (channel) =>
          stocks = @mapStock result.root, channel.id
          @initMatcher().then () =>
            @createOrUpdate stocks, callback
          .fail (msg) =>
            @returnResult false, msg, callback
        .fail (msg) =>
          @returnResult false, msg, callback

  mapStock: (xmljs, channelId) ->
    stocks = []
    for k,row of xmljs.row
      sku = xmlHelpers.xmlVal row, 'code'
      stocks.push @createInventoryEntry(sku, xmlHelpers.xmlVal(row, 'quantity'), xmlHelpers.xmlVal(row, 'CommittedDeliveryDate'))
      expectedQuantity = xmlHelpers.xmlVal row, 'AppointedQuantity'
      if expectedQuantity
        d = @createInventoryEntry(sku, expectedQuantity, xmlHelpers.xmlVal(row, 'deliverydate'), channelId)
        stocks.push d
    stocks

module.exports = StockXmlImport