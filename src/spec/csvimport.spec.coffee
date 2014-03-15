_ = require('underscore')._
Config = require '../config'
StockXmlImport = require('../main').StockXmlImport
Csv = require 'csv'

describe '#_mapStockFromCSV', ->
  beforeEach ->
    @import = new StockXmlImport {}

  it 'simple entry', (done) ->
    rawCSV =
      '''
      stock,quantity
      123,1
      '''
    Csv().from.string(rawCSV).to.array (data, count) =>
      stocks = @import._mapStockFromCSV _.rest(data)
      expect(stocks.length).toBe 1
      s = stocks[0]
      expect(s.sku).toBe '123'
      expect(s.quantityOnStock).toBe 1
      done()
