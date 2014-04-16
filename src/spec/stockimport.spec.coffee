Q = require 'q'
_ = require 'underscore'
Csv = require 'csv'
{Logger} = require 'sphere-node-utils'
package_json = require '../package.json'
Config = require '../config'
xmlHelpers = require '../lib/xmlhelpers.js'
StockImport = require '../lib/stockimport'

describe 'StockImport', ->
  beforeEach ->
    logger = new Logger
      name: "#{package_json.name}-#{package_json.version}:#{Config.config.project_key}"
      streams: [
        { level: 'info', stream: process.stdout }
      ]
    @import = new StockImport
      config: Config.config
      logConfig:
        logger: logger
      csvHeaders: 'id, amount'
      csvDelimiter: ','

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

  describe '#_getHeaderIndexes', ->
    it 'should reject if no sku header found', (done) ->
      @import._getHeaderIndexes ['bla', 'foo', 'quantity', 'price'], 'sku, q'
      .then (msg) -> done msg
      .fail (err) ->
        expect(err).toBe "Can't find header 'sku' in 'bla,foo,quantity,price'."
        done()

    it 'should reject if no quantity header found', (done) ->
      @import._getHeaderIndexes ['sku', 'price', 'quality'], 'sku, quantity'
      .fail (err) ->
        expect(err).toBe "Can't find header 'quantity' in 'sku,price,quality'."
        done()
      .then (msg) -> done msg

    it 'should return the indexes of the two named columns', (done) ->
      @import._getHeaderIndexes ['foo', 'q', 'bar', 's'], 's, q'
      .then (indexes) ->
        expect(indexes[0]).toBe 3
        expect(indexes[1]).toBe 1
        done()
      .fail (err) ->
        done err

  describe '#_mapStockFromCSV', ->

    it 'simple entry', (done) ->
      rawCSV =
        '''
        id,amount
        123,77
        abc,-3
        '''
      Csv().from.string(rawCSV).to.array (data, count) =>
        stocks = @import._mapStockFromCSV _.rest(data)
        expect(_.size stocks).toBe 2
        s = stocks[0]
        expect(s.sku).toBe '123'
        expect(s.quantityOnStock).toBe 77
        s = stocks[1]
        expect(s.sku).toBe 'abc'
        expect(s.quantityOnStock).toBe -3
        done()

  describe '#performCSV', ->

    it 'should parse with a custom delimiter', (done) ->
      rawCSV =
        '''
        id;amount
        123;77
        abc;-3
        '''
      @import.csvDelimiter = ';'
      spyOn(@import, '_perform').andReturn Q()
      spyOn(@import, '_getHeaderIndexes').andCallThrough()
      @import.performCSV(rawCSV)
      .then (result) =>
        expect(@import._getHeaderIndexes).toHaveBeenCalledWith ['id', 'amount'], 'id, amount'
        done()
      .fail (error) -> done error
