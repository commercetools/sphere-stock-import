_ = require 'underscore'
Csv = require 'csv'
xmlHelpers = require '../lib/xmlhelpers.js'
StockImport = require '../lib/stockimport'

describe 'StockImport', ->
  beforeEach ->
    @import = new StockImport()

  it 'should initialize', ->
    expect(@import).toBeDefined()

  describe '#_mapStockFromXML', ->
    it 'simple entry', (done) ->
      rawXml =
        '''
        <root>
          <row>
            <code>1</code>
            <quantity>2</quantity>
          </row>
        </root>
        '''
      xml = xmlHelpers.xmlFix(rawXml)
      xmlHelpers.xmlTransform xml, (err, result) =>
        stocks = @import._mapStockFromXML result.root
        expect(stocks.length).toBe 1
        s = stocks[0]
        expect(s.sku).toBe '1'
        expect(s.quantityOnStock).toBe 2
        done()

    it 'should not map delivery date when no AppointedQuantity given', (done) ->
      rawXml =
        '''
        <root>
          <row>
            <code>2</code>
            <quantity>7.000</quantity>
            <CommittedDeliveryDate>2013-11-19T00:00:00</CommittedDeliveryDate>
          </row>
        </root>
        '''
      xml = xmlHelpers.xmlFix(rawXml)
      xmlHelpers.xmlTransform xml, (err, result) =>
        stocks = @import._mapStockFromXML result.root
        expect(stocks.length).toBe 1
        s = stocks[0]
        expect(s.sku).toBe '2'
        expect(s.quantityOnStock).toBe 7
        expect(s.expectedDelivery).toBeUndefined()
        done()

    it 'should map an extra entry for AppointedQuantity', (done) ->
      rawXml =
        '''
        <root>
          <row>
            <code>foo-bar</code>
            <quantity>7.000</quantity>
            <AppointedQuantity>12.000</AppointedQuantity>
          </row>
        </root>
        '''
      xml = xmlHelpers.xmlFix(rawXml)
      xmlHelpers.xmlTransform xml, (err, result) =>
        stocks = @import._mapStockFromXML result.root, 'myChannelId'
        expect(stocks.length).toBe 2
        s = stocks[0]
        expect(s.sku).toBe 'foo-bar'
        expect(s.quantityOnStock).toBe 7
        expect(s.expectedDelivery).toBeUndefined()
        s = stocks[1]
        expect(s.sku).toBe 'foo-bar'
        expect(s.quantityOnStock).toBe 12
        expect(s.expectedDelivery).toBeUndefined()
        expect(s.supplyChannel.typeId).toBe 'channel'
        expect(s.supplyChannel.id).toBe 'myChannelId'
        done()

  describe '#_mapStockFromCSV', ->
    it 'simple entry', (done) ->
      stockimport = new StockImport()
      rawCSV =
        '''
        stock,quantity
        123,77
        abc,-3
        '''
      Csv().from.string(rawCSV).to.array (data, count) ->
        stocks = stockimport._mapStockFromCSV _.rest(data)
        expect(_.size stocks).toBe 2
        s = stocks[0]
        expect(s.sku).toBe '123'
        expect(s.quantityOnStock).toBe 77
        s = stocks[1]
        expect(s.sku).toBe 'abc'
        expect(s.quantityOnStock).toBe -3
        done()