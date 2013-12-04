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
  @rest.GET "/inventory?limit=0", (error, response, body) =>
    if response.statusCode is not 200
      @returnResult false, 'Can not fetch stock information.', callback
      return
    existingStocks = JSON.parse(body).results
    sku2entry = {}
    sku2quantity = {}
    for es in existingStocks
      sku2entry[es.sku] = es
    posts = []
    for s in stocks
      if sku2entry[s.sku]
        posts.push @update(s, sku2entry[s.sku])
      else
        posts.push @create(s)
    Q.all(posts).then (v) =>
      if v.length is 1
        v = v[0]
      else
        v = "#{v.length} Done"
      @returnResult true, v, callback
    .fail (v) =>
      @returnResult false, v, callback

exports.StockXmlImport.prototype.update = (s, es) ->
  deferred = Q.defer()

  diff = s.quantityOnStock - es.quantityOnStock
  if diff is 0
    deferred.resolve 'Stock update not neccessary'
    return deferred.promise
  d =
    version: es.version
    actions: [ quantity: Math.abs diff ]
  if diff > 0
    d.actions[0].action = 'addQuantity'
  else
    d.actions[0].action = 'removeQuantity'

  @rest.POST "/inventory/#{es.id}", JSON.stringify(d), (error, response, body) =>
    if error
      deferred.reject 'Error on updating new stock.' + error
    else
      if response.statusCode is 200
        process.stdout.write "u"
        deferred.resolve 'Stock updated'
      else
        @deferred.reject 'Problem on updating existing stock.' + body
  deferred.promise

exports.StockXmlImport.prototype.create = (stock) ->
  deferred = Q.defer()
  @rest.POST '/inventory', JSON.stringify(stock), (error, response, body) =>
    if error
      deferred.reject 'Error on creating new stock.' + error
    else
      if response.statusCode is 201
        deferred.resolve 'New stock created'
        process.stdout.write "c"
      else
        deferred.reject 'Problem on creating new stock.' + body
  deferred.promise


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