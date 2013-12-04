_ = require('underscore')._
{parseString} = require 'xml2js'
Config = require '../config'
Rest = require('sphere-node-connect').Rest
Q = require 'q'

exports.StockXmlImport = (options) ->
  @_options = options
  @rest = new Rest Config
  @

exports.StockXmlImport.prototype.process = (data, callback) ->
  throw new Error 'JSON Object required' unless _.isObject data
  throw new Error 'Callback must be a function' unless _.isFunction callback

  if data.attachments
    for k,v of data.attachments
      @transform @getAndFix(v), (stocks) =>
        @createOrUpdate stocks, callback
  else
    @returnResult false, 'No XML data attachments found.', callback

exports.StockXmlImport.prototype.returnResult = (positiveFeedback, msg, callback) ->
  d =
    message:
      status: positiveFeedback
      msg: msg
  console.log 'Error occurred: %j', d if not positiveFeedback
  callback d

exports.StockXmlImport.prototype.createOrUpdate = (stocks, callback) ->
  @rest.GET "/inventory", (error, response, body) =>
    if response.statusCode is not 200
      @returnResult false, 'Can not fetch stock information.', callback
      return
    existingStocks = JSON.parse(body).results
    sku2id = {}
    sku2quantity = {}
    for es in existingStocks
      sku2id[es.sku] = es.id
      sku2quantity[es.sku] = es.quantityOnStock
    for s in stocks
      if sku2id[s.sku]
        diff = s.quantityOnStock - sku2quantity[s.sku]
        if diff is 0
          @returnResult true, 'Stock update not neccessary', callback
          return
        d =
          version: es.version
          actions: [
            action: 'TODO'
            quantity: Math.abs diff
          ]
        if diff > 0
          d.actions[0].action = 'addQuantity'
        else
          d.actions[0].action = 'removeQuantity'
        @rest.POST "/inventory/#{es.id}", JSON.stringify(d), (error, response, body) =>
          if response.statusCode is 200
            @returnResult true, 'Stock updated', callback
          else
            @returnResult false, 'Problem on updating existing stock.' + body, callback
      else
        @rest.POST '/inventory', JSON.stringify(s), (error, response, body) =>
          if response.statusCode is 201
            @returnResult true, 'New stock created', callback
          else
            @returnResult false, 'Problem on creating new stock.' + body, callback

exports.StockXmlImport.prototype.getAndFix = (raw) ->
  #TODO: decode base64 - make configurable for testing
  "<?xml?><root>#{raw}</root>"

exports.StockXmlImport.prototype.transform = (xml, callback) ->
  parseString xml, (err, result) =>
    @returnResult false, 'Error on parsing XML:' + err, callback if err
    @mapStock result.root, callback

exports.StockXmlImport.prototype.mapStock = (xmljs, callback) ->
  stocks = []
  for k,row of xmljs.row
    d =
      sku: @val row, 'code'
      quantityOnStock: parseInt(@val row, 'quantity')
    stocks.push d
  callback(stocks)

exports.StockXmlImport.prototype.val = (row, name, fallback) ->
  return row[name][0] if row[name]
  fallback