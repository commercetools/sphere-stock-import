_ = require 'underscore'
_.mixin require('underscore-mixins')
Promise = require 'bluebird'
{ExtendedLogger} = require 'sphere-node-utils'
package_json = require '../package.json'
Config = require '../config'
StockImport = require '../lib/stockimport'
{customTypePayload1, customTypePayload2, customTypePayload3} = require './helper-customTypePayload.spec'

cleanup = (logger, client) ->
  logger.debug 'Deleting old inventory entries...'
  client.inventoryEntries.all().fetch()
  .then (result) ->
    Promise.all _.map result.body.results, (e) ->
      client.inventoryEntries.byId(e.id).delete(e.version)
  .then (results) ->
    logger.debug "Inventory #{_.size results} deleted."
    logger.debug 'Deleting old types entries...'
    client.types.all().fetch()
  .then (result) ->
    Promise.all _.map result.body.results, (e) ->
      client.types.byId(e.id).delete(e.version)
  .then (results) ->
    logger.debug "Types #{_.size results} deleted."
    logger.debug 'Deleting old channels entries...'
    client.channels.all().fetch()
  .then (result) ->
    Promise.all _.map result.body.results, (e) ->
      client.channels.byId(e.id).delete(e.version)
  .then (results) ->
    logger.debug "Channels #{_.size results} deleted."
    Promise.resolve()

describe 'integration test', ->

  beforeEach (done) ->
    @logger = new ExtendedLogger
      additionalFields:
        project_key: Config.config.project_key
      logConfig:
        name: "#{package_json.name}-#{package_json.version}"
        streams: [
          { level: 'info', stream: process.stdout }
        ]
    @stockimport = new StockImport @logger,
      config: Config.config
      csvHeaders: 'sku,quantityOnStock'
      csvDelimiter: ','

    @client = @stockimport.client

    @logger.info 'About to setup...'
    cleanup(@logger, @client)
    .then =>
      done()
    .catch (err) -> done(_.prettify err)
  , 10000 # 10sec

  afterEach (done) ->
    @logger.info 'About to cleanup...'
    cleanup(@logger, @client)
    .then -> done()
    .catch (err) -> done(_.prettify err)
  , 10000 # 10sec

  describe 'XML file', ->

    it 'Nothing to do', (done) ->
      @stockimport.run('<root></root>', 'XML')
      .then => @stockimport.summaryReport()
      .then (message) ->
        expect(message).toBe 'Summary: nothing to do, everything is fine'
        done()
      .catch (err) -> done(_.prettify err)
    , 10000 # 10sec

    it 'one new stock', (done) ->
      rawXml =
        '''
        <root>
          <row>
            <code>123</code>
            <quantity>2</quantity>
          </row>
        </root>
        '''
      @stockimport.run(rawXml, 'XML')
      .then => @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: there were 1 imported stocks (1 were new and 0 were updates)'
        @client.inventoryEntries.fetch()
      .then (result) =>
        stocks = result.body.results
        expect(_.size stocks).toBe 1
        expect(stocks[0].sku).toBe '123'
        expect(stocks[0].quantityOnStock).toBe 2
        @stockimport.run(rawXml, 'XML')
      .then => @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: nothing to do, everything is fine'
        @client.inventoryEntries.fetch()
      .then (result) ->
        stocks = result.body.results
        expect(_.size stocks).toBe 1
        expect(stocks[0].sku).toBe '123'
        expect(stocks[0].quantityOnStock).toBe 2
        done()
      .catch (err) -> done(_.prettify err)
    , 10000 # 10sec

    it 'add more stock', (done) ->
      rawXml =
        '''
        <root>
          <row>
            <code>234</code>
            <quantity>7</quantity>
          </row>
        </root>
        '''
      rawXmlChanged = rawXml.replace('7', '19')
      @stockimport.run(rawXml, 'XML')
      .then => @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: there were 1 imported stocks (1 were new and 0 were updates)'
        @client.inventoryEntries.fetch()
      .then (result) =>
        stocks = result.body.results
        expect(_.size stocks).toBe 1
        expect(stocks[0].sku).toBe '234'
        expect(stocks[0].quantityOnStock).toBe 7
        @stockimport.run(rawXmlChanged, 'XML')
      .then => @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: there were 1 imported stocks (0 were new and 1 were updates)'
        @client.inventoryEntries.fetch()
      .then (result) ->
        stocks = result.body.results
        expect(_.size stocks).toBe 1
        expect(stocks[0].sku).toBe '234'
        expect(stocks[0].quantityOnStock).toBe 19
        done()
      .catch (err) -> done(_.prettify err)
    , 10000 # 10sec

    it 'remove some stock', (done) ->
      rawXml =
        '''
        <root>
          <row>
            <code>1234567890</code>
            <quantity>77</quantity>
          </row>
        </root>
        '''
      rawXmlChanged = rawXml.replace('77', '-13')
      @stockimport.run(rawXml, 'XML')
      .then => @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: there were 1 imported stocks (1 were new and 0 were updates)'
        @client.inventoryEntries.fetch()
      .then (result) =>
        stocks = result.body.results
        expect(_.size stocks).toBe 1
        expect(stocks[0].sku).toBe '1234567890'
        expect(stocks[0].quantityOnStock).toBe 77
        @stockimport.run(rawXmlChanged, 'XML')
      .then => @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: there were 1 imported stocks (0 were new and 1 were updates)'
        @client.inventoryEntries.fetch()
      .then (result) ->
        stocks = result.body.results
        expect(_.size stocks).toBe 1
        expect(stocks[0].sku).toBe '1234567890'
        expect(stocks[0].quantityOnStock).toBe -13
        done()
      .catch (err) -> done(_.prettify err)
    , 10000 # 10sec

    it 'should create and update 2 stock entries when appointed quantity is given', (done) ->
      rawXml =
        '''
        <root>
          <row>
            <code>myEAN</code>
            <quantity>-1</quantity>
            <appointedquantity>10</appointedquantity>
            <committeddeliverydate>1999-12-31T11:11:11.000Z</committeddeliverydate>
          </row>
        </root>
        '''
      rawXmlChangedAppointedQuantity = rawXml.replace('10', '20')
      rawXmlChangedCommittedDeliveryDate = rawXml.replace('1999-12-31T11:11:11.000Z', '2000-01-01T12:12:12.000Z')
      rawXmlEmptyValues = rawXml.replace('10', '').replace('1999-12-31T11:11:11.000Z', '')

      @stockimport.run(rawXml, 'XML')
      .then => @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: there were 2 imported stocks (2 were new and 0 were updates)'
        @client.inventoryEntries.sort('id').fetch()
      .then (result) =>
        stocks = result.body.results
        expect(stocks.length).toBe 2

        stockA = _.find stocks, (s) -> s.quantityOnStock is -1
        expect(stockA).toBeDefined()
        expect(stockA.sku).toBe 'myEAN'
        expect(stockA.quantityOnStock).toBe -1
        expect(stockA.supplyChannel).toBeUndefined()

        stockB = _.find stocks, (s) -> s.quantityOnStock is 10
        expect(stockB).toBeDefined()
        expect(stockB.sku).toBe 'myEAN'
        expect(stockB.quantityOnStock).toBe 10
        expect(stockB.supplyChannel).toBeDefined()
        expect(stockB.expectedDelivery).toBe '1999-12-31T11:11:11.000Z'

        @stockimport.run(rawXmlChangedAppointedQuantity, 'XML')
      .then => @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: there were 1 imported stocks (0 were new and 1 were updates)'
        @client.inventoryEntries.sort('id').fetch()
      .then (result) =>
        stocks = result.body.results

        stockA = _.find stocks, (s) -> s.quantityOnStock is -1
        expect(stockA).toBeDefined()
        expect(stockA.sku).toBe 'myEAN'
        expect(stockA.quantityOnStock).toBe -1
        expect(stockA.supplyChannel).toBeUndefined()

        stockB = _.find stocks, (s) -> s.quantityOnStock is 20
        expect(stockB).toBeDefined()
        expect(stockB.sku).toBe 'myEAN'
        expect(stockB.quantityOnStock).toBe 20
        expect(stockB.supplyChannel).toBeDefined()
        expect(stockB.expectedDelivery).toBe '1999-12-31T11:11:11.000Z'

        @stockimport.run(rawXmlChangedCommittedDeliveryDate, 'XML')
      .then => @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: there were 1 imported stocks (0 were new and 1 were updates)'
        @client.inventoryEntries.sort('id').fetch()
      .then (result) =>
        stocks = result.body.results

        stockA = _.find stocks, (s) -> s.quantityOnStock is -1
        expect(stockA).toBeDefined()
        expect(stockA.sku).toBe 'myEAN'
        expect(stockA.quantityOnStock).toBe -1
        expect(stockA.supplyChannel).toBeUndefined()

        stockB = _.find stocks, (s) -> s.quantityOnStock is 10
        expect(stockB).toBeDefined()
        expect(stockB.sku).toBe 'myEAN'
        expect(stockB.quantityOnStock).toBe 10
        expect(stockB.supplyChannel).toBeDefined()
        expect(stockB.expectedDelivery).toBe '2000-01-01T12:12:12.000Z'

        @stockimport.run(rawXmlChangedCommittedDeliveryDate, 'XML')
      .then => @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: nothing to do, everything is fine'
        @client.inventoryEntries.sort('id').fetch()
      .then (result) =>
        stocks = result.body.results

        stockA = _.find stocks, (s) -> s.quantityOnStock is -1
        expect(stockA).toBeDefined()
        expect(stockA.sku).toBe 'myEAN'
        expect(stockA.quantityOnStock).toBe -1
        expect(stockA.supplyChannel).toBeUndefined()

        stockB = _.find stocks, (s) -> s.quantityOnStock is 10
        expect(stockB).toBeDefined()
        expect(stockB.sku).toBe 'myEAN'
        expect(stockB.quantityOnStock).toBe 10
        expect(stockB.supplyChannel).toBeDefined()
        expect(stockB.expectedDelivery).toBe '2000-01-01T12:12:12.000Z'

        @stockimport.run(rawXmlEmptyValues, 'XML')
      .then => @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: there were 1 imported stocks (0 were new and 1 were updates)'
        @client.inventoryEntries.sort('id').fetch()
      .then (result) ->
        stocks = result.body.results

        stockA = _.find stocks, (s) -> s.quantityOnStock is -1
        expect(stockA).toBeDefined()
        expect(stockA.sku).toBe 'myEAN'
        expect(stockA.quantityOnStock).toBe -1
        expect(stockA.supplyChannel).toBeUndefined()

        stockB = _.find stocks, (s) -> s.quantityOnStock is 0
        expect(stockB).toBeDefined()
        expect(stockB.sku).toBe 'myEAN'
        expect(stockB.quantityOnStock).toBe 0
        expect(stockB.supplyChannel).toBeDefined()
        expect(stockB.expectedDelivery).toBeUndefined()

        done()
      .catch (err) -> done(_.prettify err)
    , 20000 # 20sec

  describe 'CSV file', ->

    it 'CSV - one new stock', (done) ->
      raw =
        '''
        sku,quantityOnStock
        abcd,0
        '''
      @stockimport.run(raw, 'CSV')
      .then =>
        @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: there were 1 imported stocks (1 were new and 0 were updates)'
        @client.inventoryEntries.fetch()
      .then (result) =>
        stocks = result.body.results
        expect(_.size stocks).toBe 1
        expect(stocks[0].sku).toBe 'abcd'
        expect(stocks[0].quantityOnStock).toBe 0
        @stockimport.run(raw, 'CSV')
      .then => @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: nothing to do, everything is fine'
        @client.inventoryEntries.fetch()
      .then (result) ->
        stocks = result.body.results
        expect(_.size stocks).toBe 1
        expect(stocks[0].sku).toBe 'abcd'
        expect(stocks[0].quantityOnStock).toBe 0
        done()
      .catch (err) -> done(_.prettify err)
    , 10000 # 10sec

  describe 'CSV file', =>
    testChannel = undefined
    testChannel2 = undefined

    beforeEach (done) ->

      # Clear memoize cache
      @stockimport._getCustomTypeDefinition.cache = {}

      @logger.info 'About to setup...'
      cleanup(@logger, @client)
      .then =>
        @client.types.create(customTypePayload1())
      .then =>
        @client.types.create(customTypePayload2())
      .then =>
        @client.types.create(customTypePayload3())
      .then (res) =>
        @client.channels.create(key: 'testchannel').then (result) ->
          testChannel = result.body
      .then (res) =>
        @client.channels.create(key: 'testchannel2').then (result) ->
          testChannel2 = result.body
          done()
      .catch (err) -> done(_.prettify err)
    , 10000 # 10sec

    afterEach (done) ->
      @logger.info 'About to cleanup...'
      cleanup(@logger, @client)
      .then -> done()
      .catch (err) -> done(_.prettify err)
    , 10000 # 10sec

    it 'CSV - one new stock', (done) ->
      raw =
        """
        sku,quantityOnStock,restockableInDays,expectedDelivery,supplyChannel,customType,customField.quantityFactor,customField.color,customField.localizedString.de,customField.localizedString.en
        another2,77,12,2001-09-11T14:00:00.000Z,#{testChannel.key},my-type,12,nac,Schneidder,Abi
        """
      @stockimport.run(raw, 'CSV')
      .then =>
        @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: there were 1 imported stocks (1 were new and 0 were updates)'
        @client.inventoryEntries.fetch()
      .then (result) =>
        stocks = result.body.results
        expect(_.size stocks).toBe 1
        expect(stocks[0].sku).toBe 'another2'
        expect(stocks[0].quantityOnStock).toBe 77
        @stockimport.run(raw, 'CSV')
      .then => @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: nothing to do, everything is fine'
        @client.inventoryEntries.fetch()
      .then (result) ->
        stocks = result.body.results
        expect(_.size stocks).toBe 1
        expect(stocks[0].sku).toBe 'another2'
        expect(stocks[0].quantityOnStock).toBe 77
        done()
      .catch (err) ->
        done(_.prettify err)
    , 10000 # 10sec

    it 'CSV - should ignore empty fields in customFields', (done) ->
      raw =
        """
        sku,quantityOnStock,restockableInDays,expectedDelivery,customType,customField.quantityFactor,customField.color,customField.another,customField.localizedString.de,customField.localizedString.en
        another3,77,12,2001-09-11T14:00:00.000Z,my-type,12,nac,,Schneidder,Abi
        another10,77,12,2001-09-11T14:00:00.000Z,my-type2,12,,okay,Schneidder,Abi
        """

      @stockimport.run(raw, 'CSV')
      .then =>
        @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: there were 2 imported stocks (2 were new and 0 were updates)'
        @client.inventoryEntries.fetch()
      .then (result) =>
        stocks = result.body.results
        expect(_.size stocks).toBe 2
        stock1 = _.find stocks, (stock) -> stock.sku is 'another3'
        stock2 = _.find stocks, (stock) -> stock.sku is 'another10'
        expect(stock1).toBeDefined()
        expect(stock1.quantityOnStock).toBe 77
        expect(stock1.custom.fields.another).not.toBeDefined()
        expect(stock2.custom.fields.another).toBeDefined()
        expect(stock2.custom.fields.color).not.toBeDefined()
        expect(stock2.custom.fields.another).toBe 'okay'
        @stockimport.run(raw, 'CSV')
      .then => @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: nothing to do, everything is fine'
        @client.inventoryEntries.fetch()
      .then (result) ->
        stocks = result.body.results
        expect(_.size stocks).toBe 2
        stock1 = _.find stocks, (stock) -> stock.sku is 'another3'
        expect(stock1.sku).toBe 'another3'
        expect(stock1.quantityOnStock).toBe 77
        done()
      .catch (err) ->
        console.log JSON.stringify(err, null,2)
        done(_.prettify err)
    , 10000 # 10sec

    it 'CSV - update stock', (done) ->
      raw =
        """
        sku,quantityOnStock,restockableInDays,expectedDelivery,supplyChannel,customType,customField.quantityFactor,customField.color,customField.localizedString.de,customField.localizedString.en
        another2,77,12,2001-09-11T14:00:00.000Z,#{testChannel2.key},my-type1,12,nac,Schneidder,Abi
        """
      raw2 =
        """
        sku,quantityOnStock,restockableInDays,expectedDelivery,supplyChannel,customType,customField.quantityFactor,customField.color,customField.localizedString.de,customField.localizedString.en
        another2,72,10,2001-08-11T14:00:00.000Z,#{testChannel2.key},my-type1,12,blue,Schneidder,Josh
        """
      @stockimport.run(raw, 'CSV')
      .then =>
        @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: there were 1 imported stocks (1 were new and 0 were updates)'
        @client.inventoryEntries.fetch()
      .then (result) =>
        stocks = result.body.results
        expect(_.size stocks).toBe 1
        expect(stocks[0].sku).toBe 'another2'
        expect(stocks[0].quantityOnStock).toBe 77
        @stockimport.run(raw2, 'CSV')
      .then => @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: there were 1 imported stocks (0 were new and 1 were updates)'
        @client.inventoryEntries.fetch()
      .then (result) ->
        stocks = result.body.results
        expect(_.size stocks).toBe 1
        expect(stocks[0].sku).toBe 'another2'
        expect(stocks[0].quantityOnStock).toBe 72
        expect(stocks[0].custom.fields.localizedString.en).toBe 'Josh'
        expect(stocks[0].custom.fields.color).toBe 'blue'
        done()
      .catch (err) ->
        done(_.prettify err)
    , 10000 # 10sec

    it 'CSV - API should return error if required header is missing', (done) ->
      raw =
        """
        sku,invalidheader,restockableInDays,expectedDelivery,supplyChannel,customType,customField.quantityFactor,customField.color,customField.localizedString.de,customField.localizedString.en
        another2,77,12,2001-09-11T14:00:00.000Z,#{testChannel2.key},my-type1,12,nac,Schneidder,Abi
        """
      @stockimport.run(raw, 'CSV')
      .then (result)=>
        expect(result).not.toBeDefined
      .catch (err) ->
        expect(err).toBeDefined()
        expect(err.message).toBe 'Request body does not contain valid JSON.'
        expect(err.body.errors.length).toBe 1
        expect(err.body.errors[0].detailedErrorMessage).toBe 'quantityOnStock: Missing required value'
        done()
    , 10000 # 10sec
