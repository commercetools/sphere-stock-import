_ = require 'underscore'
{ExtendedLogger} = require 'sphere-node-utils'
package_json = require '../package.json'
Config = require '../config'
StockImport = require '../lib/stockimport'
{ cleanup } = require './utils.spec'

describe 'zero inventories test', ->

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
      removeZeroInventories: true
      csvHeaders: 'sku,quantityOnStock'
      csvDelimiter: ','

    @client = @stockimport.client

    @logger.info 'About to setup...'
    cleanup(@logger, @client)
    .then =>
      done()
    .catch (err) -> done(err)
  , 10000 # 10sec

  afterEach (done) ->
    @logger.info 'About to cleanup...'
    cleanup(@logger, @client)
    .then -> done()
    .catch (err) -> done(err)
  , 10000 # 10sec

  describe 'create zero inventory', ->

    it 'should ignore creation', (done) ->
      raw =
        '''
        sku,quantityOnStock
        new-inventory0,0
        new-inventory1,0
        '''
      @stockimport.run(raw, 'CSV')
        .then =>
          @stockimport.summaryReport()
        .then (message) =>
          expect(message).toBe 'Summary: nothing to do, everything is fine'
          @client.inventoryEntries.fetch()
        .then (result) =>
          expect(result.body.count).toBe 0
          done()
        .catch (err) -> done(err)
    , 5000 # 5sec

  describe 'update to zero inventory', ->

    it 'should remove instead of updating', (done) ->
      raw =
        '''
        sku,quantityOnStock
        abcd,123
        '''
      @stockimport.run(raw, 'CSV')
      .then =>
        @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: there were 1 imported stocks (1 were new, 0 were updates and 0 were deletions)'

        raw =
        '''
        sku,quantityOnStock
        abcd,0
        '''
        @stockimport.run(raw, 'CSV')
      .then =>
        @stockimport.summaryReport()
      .then (message) =>
        expect(message).toBe 'Summary: there were 0 imported stocks (0 were new, 0 were updates and 1 were deletions)'
        @client.inventoryEntries.fetch()
      .then (result) ->
        expect(result.body.count).toBe 0
        done()
      .catch (err) -> done(err)
    , 10000 # 10sec

  describe 'remove existing zero inventories', ->

    it 'should remove zero inventories', (done) ->
      raw =
        '''
        sku,quantityOnStock
        valid-inventory,123
        zero-inventory0,0
        zero-inventory1,0
        '''

      # allow importer to create zero inventories
      @stockimport.shouldRemoveZeroInventories = false

      @stockimport.run(raw, 'CSV')
        .then =>
          @stockimport.shouldRemoveZeroInventories = true

          @stockimport.removeZeroInventories()
        .then (removedInventoriesCount) =>
          expect(removedInventoriesCount).toBe(2)
          @client.inventoryEntries.fetch()
        .then (result) ->
          expect(result.body.count).toBe 1

          existingInventory = result.body.results[0]
          expect(existingInventory.sku).toBe('valid-inventory')
          done()
        .catch (err) -> done(err)
    , 10000 # 10sec
