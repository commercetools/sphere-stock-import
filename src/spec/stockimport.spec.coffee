_ = require 'underscore'
_.mixin require('underscore-mixins')
Promise = require 'bluebird'
Csv = require 'csv'
{ExtendedLogger} = require 'sphere-node-utils'
package_json = require '../package.json'
Config = require '../config'
xmlHelpers = require '../lib/xmlhelpers.js'
StockImport = require '../lib/stockimport'

describe 'StockImport', ->
  beforeEach ->
    logger = new ExtendedLogger
      logConfig:
        name: "#{package_json.name}-#{package_json.version}"
        streams: [
          { level: 'info', stream: process.stdout }
        ]
    @import = new StockImport logger,
      config: Config.config
      csvHeaders: 'id, amount'
      csvDelimiter: ','

  it 'should initialize', ->
    expect(@import).toBeDefined()
    expect(@import.client).toBeDefined()
    expect(@import.client.constructor.name).toBe 'SphereClient'
    expect(@import.sync).toBeDefined()
    expect(@import.sync.constructor.name).toBe 'InventorySync'


  describe '::summaryReport', ->

    it 'should return a report (nothing to do)', ->
      expect(@import.summaryReport('./foo.json')).toEqual 'Summary: nothing to do, everything is fine'

    it 'should return a report (with updates)', ->
      @import._summary =
        emptySKU: 2
        created: 5
        updated: 10
      message = 'Summary: there were 15 imported stocks (5 were new and 10 were updates)' +
       '\nFound 2 empty SKUs from file input \'./foo.json\''
      expect(@import.summaryReport('./foo.json')).toEqual message


  describe '::_uniqueStocksBySku', ->

    it 'should filter duplicate skus', ->
      stocks = [{sku: 'foo'}, {sku: 'bar'}, {sku: 'baz'}, {sku: 'foo'}]
      uniqueStocks = @import._uniqueStocksBySku(stocks)
      expect(uniqueStocks.length).toBe 3
      expect(_.pluck(uniqueStocks, 'sku')).toEqual ['foo', 'bar', 'baz']


  describe '::_mapStockFromXML', ->

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

    it 'should not map delivery date when no appointedquantity given', (done) ->
      rawXml =
        '''
        <root>
          <row>
            <code>2</code>
            <quantity>7.000</quantity>
            <committeddeliverydate>2013-11-19T00:00:00</committeddeliverydate>
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

    it 'should map an extra entry for appointedquantity', (done) ->
      rawXml =
        '''
        <root>
          <row>
            <code>foo-bar</code>
            <quantity>7.000</quantity>
            <appointedquantity>12.000</appointedquantity>
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

    it 'should map to zero if value for appointedquantity is empty', (done) ->
      rawXml =
        '''
        <root>
          <row>
            <code>foo-bar-123</code>
            <quantity>-14.000</quantity>
            <appointedquantity></appointedquantity>
          </row>
        </root>
        '''
      xml = xmlHelpers.xmlFix(rawXml)
      xmlHelpers.xmlTransform xml, (err, result) =>
        stocks = @import._mapStockFromXML result.root, 'myChannelId'
        expect(stocks.length).toBe 2
        s = stocks[0]
        expect(s.sku).toBe 'foo-bar-123'
        expect(s.quantityOnStock).toBe -14
        expect(s.expectedDelivery).toBeUndefined()
        s = stocks[1]
        expect(s.sku).toBe 'foo-bar-123'
        expect(s.quantityOnStock).toBe 0
        expect(s.expectedDelivery).toBeUndefined()
        expect(s.supplyChannel.typeId).toBe 'channel'
        expect(s.supplyChannel.id).toBe 'myChannelId'
        done()

    it 'should map empty date', (done) ->
      rawXml =
        '''
        <root>
          <row>
            <code>foo-bar-123</code>
            <quantity>-14.000</quantity>
            <appointedquantity></appointedquantity>
            <committeddeliverydate></committeddeliverydate>
          </row>
        </root>
        '''
      xml = xmlHelpers.xmlFix(rawXml)
      xmlHelpers.xmlTransform xml, (err, result) =>
        stocks = @import._mapStockFromXML result.root, 'myChannelId'
        expect(stocks.length).toBe 2
        s = stocks[0]
        expect(s.sku).toBe 'foo-bar-123'
        expect(s.quantityOnStock).toBe -14
        expect(s.expectedDelivery).toBeUndefined()
        s = stocks[1]
        expect(s.sku).toBe 'foo-bar-123'
        expect(s.quantityOnStock).toBe 0
        expect(s.expectedDelivery).toBeUndefined()
        expect(s.supplyChannel.typeId).toBe 'channel'
        expect(s.supplyChannel.id).toBe 'myChannelId'
        done()

    it 'should handle non ISO date by ignoring it', (done) ->
      rawXml =
        '''
        <root>
          <row>
            <code>foo-bar-xyz</code>
            <quantity>-14.000</quantity>
            <appointedquantity>123</appointedquantity>
            <committeddeliverydate>Aug 29 2014 12:00AM</committeddeliverydate>
          </row>
        </root>
        '''
      xml = xmlHelpers.xmlFix(rawXml)
      xmlHelpers.xmlTransform xml, (err, result) =>
        stocks = @import._mapStockFromXML result.root, 'myChannelId'
        expect(stocks.length).toBe 2
        s = stocks[0]
        expect(s.sku).toBe 'foo-bar-xyz'
        expect(s.quantityOnStock).toBe -14
        expect(s.expectedDelivery).toBeUndefined()
        s = stocks[1]
        expect(s.sku).toBe 'foo-bar-xyz'
        expect(s.quantityOnStock).toBe 123
        expect(s.expectedDelivery).toBeUndefined()
        expect(s.supplyChannel.typeId).toBe 'channel'
        expect(s.supplyChannel.id).toBe 'myChannelId'
        done()


  describe '::_getHeaderIndexes', ->
    it 'should reject if no sku header found', (done) ->
      @import._getHeaderIndexes ['bla', 'foo', 'quantity', 'price'], 'sku, q'
      .then (msg) -> done msg
      .catch (err) ->
        expect(err).toBe "Can't find header 'sku' in 'bla,foo,quantity,price'."
        done()

    it 'should reject if no quantity header found', (done) ->
      @import._getHeaderIndexes ['sku', 'price', 'quality'], 'sku, quantity'
      .catch (err) ->
        expect(err).toBe "Can't find header 'quantity' in 'sku,price,quality'."
        done()
      .then (msg) -> done msg

    it 'should return the indexes of the two named columns', (done) ->
      @import._getHeaderIndexes ['foo', 'q', 'bar', 's'], 's, q'
      .then (indexes) ->
        expect(indexes[0]).toBe 3
        expect(indexes[1]).toBe 1
        done()
      .catch (err) -> done(_.prettify err)


  describe '::_mapStockFromCSV', ->

    it 'should map a simple entry', (done) ->
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

    it 'shoud not crash when quantity is missing', (done) ->
      rawCSV =
        '''
        foo,id,amount
        bar,abc
        bar,123,77
        '''
      Csv().from.string(rawCSV).to.array (data, count) =>
        stocks = @import._mapStockFromCSV _.rest(data), 1, 2
        expect(_.size stocks).toBe 2
        s = stocks[0]
        expect(s.sku).toBe 'abc'
        expect(s.quantityOnStock).toBe 0
        s = stocks[1]
        expect(s.sku).toBe '123'
        expect(s.quantityOnStock).toBe 77
        done()

    xit 'shoud not crash when quantity is missing', (done) ->
      rawCSV =
        '''
        foo,id,amount
        bar
        '''
      Csv().from.string(rawCSV).to.array (data, count) =>
        stocks = @import._mapStockFromCSV _.rest(data), 1, 2
        expect(_.size stocks).toBe 0
        done()


  describe '::performCSV', ->

    it 'should parse with a custom delimiter', (done) ->
      rawCSV =
        '''
        id;amount
        123;77
        abc;-3
        '''
      @import.csvDelimiter = ';'
      spyOn(@import, '_perform').andReturn Promise.resolve()
      spyOn(@import, '_getHeaderIndexes').andCallThrough()
      @import.performCSV(rawCSV)
      .then (result) =>
        expect(@import._getHeaderIndexes).toHaveBeenCalledWith ['id', 'amount'], 'id, amount'
        done()
      .catch (err) -> done(_.prettify err)


  describe '::performStream', ->

    it 'should execute callback after finished processing batches', (done) ->
      spyOn(@import, '_processBatches').andCallFake -> Promise.resolve()
      @import.performStream [1, 2, 3], done
      .catch (err) -> done(_.prettify err)


  describe '::_processBatches', ->

    it 'should process list of stocks in batches', (done) ->
      chunk = [
        {sku: 'foo-1', quantityOnStock: 5},
        {sku: 'foo-2', quantityOnStock: 20}
      ]
      existingEntries = [
        {sku: 'foo-1', quantityOnStock: 5},
        {sku: 'foo-2', quantityOnStock: 10}
      ]

      spyOn(@import, '_uniqueStocksBySku').andCallThrough()
      spyOn(@import, '_createOrUpdate').andCallFake -> Promise.all([Promise.resolve({statusCode: 201}), Promise.resolve({statusCode: 200})])
      spyOn(@import.client.inventoryEntries, 'fetch').andCallFake -> new Promise (resolve, reject) -> resolve({body: {results: existingEntries}})

      @import._processBatches(chunk)
      .then =>
        expect(@import._uniqueStocksBySku).toHaveBeenCalled()
        expect(@import._summary).toEqual
          emptySKU: 0
          created: 1
          updated: 1
        done()
      .catch (err) -> done(_.prettify err)


  describe '::_createOrUpdate', ->

    it 'should update and create inventory for same sku', (done) ->
      inventoryEntries = [
        {sku: 'foo', quantityOnStock: 2},
        {sku: 'foo', quantityOnStock: 3, supplyChannel: {typeId: 'channel', id: '111'}}
      ]
      existingEntries = [{id: '123', version: 1, sku: 'foo', quantityOnStock: 1}]
      expectedUpdate =
        version: 1
        actions: [
          {action: 'addQuantity', quantity: 1}
        ]
      expectedCreate =
        sku: 'foo'
        quantityOnStock: 3
        supplyChannel:
          typeId: 'channel'
          id: '111'
      spyOn(@import.client._rest, 'POST').andCallFake (endpoint, payload, callback) ->
        callback(null, {statusCode: 200}, {})
      @import._createOrUpdate inventoryEntries, existingEntries
      .then =>
        # first matched is an update (no channels)
        # second is not a match, so it's a new entry
        expect(@import.client._rest.POST.calls[0].args[1]).toEqual expectedUpdate
        expect(@import.client._rest.POST.calls[1].args[1]).toEqual expectedCreate
        done()
      .catch (err) -> done(_.prettify err)


  describe '::_match', ->

    it 'should match correct entry if there is more then one with same SKU', ->
      existingEntries = [
        {
          id: '3da09201-33c8-4b68-8719-6760a94e74b7'
          version: 4
          sku: '22009978'
          supplyChannel:
            typeId: 'channel'
            id: '239772e4-15b4-48d1-b2ad-3ac6e2c3cb21'
          quantityOnStock: 43,
          availableQuantity: 43
        },
        {
          id: '4b5b83a2-6da7-45a4-b63d-90adb719ba15',
          version: 9,
          sku: '22009978',
          quantityOnStock: 43,
          availableQuantity: 43
        }
      ]
      matchingEntry =
        sku: '22009978'
        quantityOnStock: 42
      matchingEntryWithChannel =
        sku: '22009978'
        quantityOnStock: 0
        supplyChannel:
          typeId: 'channel'
          id: '239772e4-15b4-48d1-b2ad-3ac6e2c3cb21'

      expect(@import._match(matchingEntry, existingEntries)).toEqual existingEntries[1]
      expect(@import._match(matchingEntryWithChannel, existingEntries)).toEqual existingEntries[0]
