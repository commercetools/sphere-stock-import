_ = require 'underscore'
_.mixin require('underscore-mixins')
Promise = require 'bluebird'
csv = require 'csv'
sinon = require 'sinon'
{ExtendedLogger} = require 'sphere-node-utils'
package_json = require '../package.json'
Config = require '../config'
xmlHelpers = require '../lib/xmlhelpers.js'
StockImport = require '../lib/stockimport'

{customTypePayload1} = require './helper-customTypePayload.spec'

describe 'StockImport', ->
  cleanup = (endpoint) ->
    endpoint.all().fetch()
      .then (result) ->
        Promise.all _.map result.body.results, (e) ->
          endpoint.byId(e.id).delete(e.version)

  beforeEach ->
    logger = new ExtendedLogger
      logConfig:
        name: "#{package_json.name}-#{package_json.version}"
        streams: [
          { level: 'info', stream: process.stdout }
        ]
    @import = new StockImport logger,
      config: Config.config
      csvDelimiter: ','

  it 'should initialize', ->
    expect(@import).toBeDefined()
    expect(@import.client).toBeDefined()
    expect(@import.client.constructor.name).toBe 'SphereClient'
    expect(@import.sync).toBeDefined()
    expect(@import.client?._rest?._options?.headers?['User-Agent'])
      .toBe('sphere-stock-import')
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

  describe '::_mapChannelKeyToReference', ->
    testChannel = undefined

    beforeEach (done) ->
      channelPayload = {
        "key": "mah-channel"
      }

      cleanup(@import.client.channels)
        .then =>
          @import.client.channels.create(channelPayload)
        .then((result) ->
          testChannel = result
          done()
        )
        .catch(done)

    it 'should fetch reference from key', (done) ->
      @import._mapChannelKeyToReference testChannel.body.key
        .then (result) ->
          expect(result).toEqual {typeId: 'channel', id: testChannel.body.id}
          done()

  describe '::_getCustomTypeDefinition', ->
    types = undefined
    customType = undefined

    beforeEach (done) ->
      types = @import.client.types
      cleanup(@import.client.inventoryEntries).then ->
        cleanup(types).then ->
          customTypePayload = customTypePayload1()
          types.create(customTypePayload).then (result) ->
            customType = result.body
            done()

    afterEach (done) ->
      cleanup(@import.client.types)
        .then ->
          done()

    it 'should fetch customTypeDefinition', (done) ->

      @import._getCustomTypeDefinition(customType.key).then (data) ->
        result = data.body
        expect(result).toBeDefined()
        expect(result.key).toBe(customType.key)
        expect(result.fieldDefinitions).toBeDefined()
        done()

    it 'should memoize customTypeDefinition result', (done) ->
      stub = sinon.stub(@import, '__getCustomTypeDefinition')
        .onFirstCall('first').returns(Promise.resolve('first call'))
        .onSecondCall('second').returns(Promise.resolve('second call'))
      Promise.all([
        @import._getCustomTypeDefinition('first'),
        @import._getCustomTypeDefinition('first'),
        @import._getCustomTypeDefinition('second'),
        @import._getCustomTypeDefinition('second'),
        @import._getCustomTypeDefinition('first'),
      ]).then (result) ->
        expect(result.length).toBe(5)
        expect(stub.stub.calledTwice).toBeTruthy(
          'Only two calls are made, cached result is returned for other calls'
        )
        done()

    it 'should map custom fields with type String', (done) ->
      rawCSV =
        '''
        sku,quantityOnStock,customType,customField.quantityFactor,customField.color
        123,77,my-type,12,nac
        abc,-3,my-type,5,ho
        '''
      csv.parse rawCSV, (err, data) =>
        @import._mapStockFromCSV(_.rest(data), data[0]).then (stocks) ->
          expect(_.size stocks).toBe 2
          s = stocks[0]
          expect(s.sku).toBe '123'
          expect(s.quantityOnStock).toBe(77)
          expect(s.custom.type.id).toBeDefined()
          expect(s.custom.fields.quantityFactor).toBe(12)
          expect(s.custom.fields.color).toBe 'nac'
          s = stocks[1]
          expect(s.sku).toBe 'abc'
          expect(s.quantityOnStock).toBe -3
          expect(s.custom.type.id).toBeDefined()
          expect(s.custom.fields.quantityFactor).toBe 5
          expect(s.custom.fields.color).toBe 'ho'
          done()

    it 'should map custom fields with type LocalizedString', (done) ->
      rawCSV =
        '''
        sku,quantityOnStock,customType,customField.localizedString.en,customField.localizedString.de,customField.name.de
        123,77,my-type,english,deutsch,abi
        abc,-3,my-type,blue,automat,sil
        '''
      csv.parse rawCSV, (err, data) =>
        @import._mapStockFromCSV(_.rest(data), data[0])
          .then((stocks) ->
            expect(_.size stocks).toBe 2
            s = stocks[0]
            expect(s.sku).toBe '123'
            expect(s.quantityOnStock).toBe(77)
            expect(s.custom.type.id).toBeDefined()
            expect(s.custom.fields.localizedString.en).toBe 'english'
            expect(s.custom.fields.localizedString.de).toBe 'deutsch'
            expect(s.custom.fields.name.de).toBe 'abi'
            s = stocks[1]
            expect(s.sku).toBe 'abc'
            expect(s.quantityOnStock).toBe -3
            expect(s.custom.type.id).toBeDefined()
            expect(s.custom.fields.localizedString.en).toBe 'blue'
            expect(s.custom.fields.localizedString.de).toBe 'automat'
            expect(s.custom.fields.name.de).toBe 'sil'
            done())
          .catch (err) ->
            expect(err).not.toBeDefined()
            done()

    it 'should map custom fields with type Money', (done) ->
      rawCSV =
        '''
        sku,quantityOnStock,customType,customField.price,customField.color
        123,77,my-type,EUR 120,nac
        abc,-3,my-type,EUR 230,ho
        '''
      csv.parse rawCSV, (err, data) =>
        @import._mapStockFromCSV(_.rest(data), data[0]).then (stocks) ->
          expect(_.size stocks).toBe 2
          s = stocks[0]
          expect(s.sku).toBe '123'
          expect(s.quantityOnStock).toBe(77)
          expect(s.custom.type.id).toBeDefined()
          expect(s.custom.fields.price).toEqual {currencyCode: 'EUR', centAmount: 120}
          expect(s.custom.fields.color).toBe 'nac'
          s = stocks[1]
          expect(s.sku).toBe 'abc'
          expect(s.quantityOnStock).toBe -3
          expect(s.custom.type.id).toBeDefined()
          expect(s.custom.fields.price).toEqual {currencyCode: 'EUR', centAmount: 230}
          expect(s.custom.fields.color).toBe 'ho'
          done()

    it 'should report errors on data', (done) ->
      rawCSV =
        '''
        sku,quantityOnStock,customType,customField.price,customField.color
        123,77,my-type,EUR 120,nac
        abc,-3,my-type,EUR,ho
        '''
      csv.parse rawCSV, (err, data) =>
        @import._mapStockFromCSV(_.rest(data), data[0]).then((stocks) ->
          expect(stocks).not.toBeDefined()
        ).catch (err) ->
          expect(err.length).toBe 1
          expect(err.join()).toContain('Can not parse money')
          done()


  describe '::_mapStockFromCSV', ->
    it 'should map a simple entry', (done) ->
      rawCSV =
        '''
        sku,quantityOnStock
        123,77
        abc,-3
        '''
      csv.parse rawCSV, (err, data) =>
        @import._mapStockFromCSV(_.rest(data), data[0]).then (stocks) ->
          expect(_.size stocks).toBe 2
          s = stocks[0]
          expect(s.sku).toBe '123'
          expect(s.quantityOnStock).toBe 77
          s = stocks[1]
          expect(s.sku).toBe 'abc'
          expect(s.quantityOnStock).toBe -3
          done()

    it 'should not crash when quantity is missing', (done) ->
      rawCSV =
        '''
        foo,sku,quantityOnStock
        bar,abc,
        bar,123,77
        '''
      csv.parse rawCSV, (err, data) =>
        @import._mapStockFromCSV(_.rest(data), data[0]).then (stocks) ->
          expect(_.size stocks).toBe 2
          s = stocks[0]
          expect(s.sku).toBe 'abc'
          expect(s.quantityOnStock).toBe 0
          s = stocks[1]
          expect(s.sku).toBe '123'
          expect(s.quantityOnStock).toBe 77
          done()

    it 'should crash when csv columns is inconsistent', (done) ->
      # Empty columns should be represented with empty delimiter
      rawCSV =
        '''
        foo,sku,quantityOnStock
        bar,abc
        bar,123,77
        '''
      csv.parse rawCSV, (err, data) ->
        expect(err).toBeDefined()
        expect(err.message).toBe('Number of columns is inconsistent on line 2')
        expect(data).not.toBeDefined()
        done()

    xit 'shoud not crash when quantity is missing', (done) ->
      rawCSV =
        '''
        foo,sku,quantityOnStock
        bar
        '''
      csv.parse rawCSV, (err, data) =>
        @import._mapStockFromCSV(_.rest(data), data[0]).then (stocks) ->
          expect(_.size stocks).toBe 0
          done()


  describe '::performCSV', ->

    it 'should parse with a custom delimiter', (done) ->
      rawCSV =
        '''
        sku;quantityOnStock
        123;77
        abc;-3
        '''
      @import.csvDelimiter = ';'
      spyOn(@import, '_perform').andReturn Promise.resolve()
      spyOn(@import, '_mapStockFromCSV').andCallThrough()
      @import.performCSV(rawCSV)
        .then (result) =>
          expect(@import._mapStockFromCSV).toHaveBeenCalledWith [ [ '123', '77' ], [ 'abc', '-3' ] ], [ 'sku', 'quantityOnStock' ]
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
