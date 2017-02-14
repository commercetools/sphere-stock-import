_ = require 'underscore'
Promise = require 'bluebird'
{SphereClient} = require 'sphere-node-sdk'
{ExtendedLogger, ElasticIo} = require 'sphere-node-utils'
package_json = require '../package.json'
Config = require '../config'
elasticio = require '../lib/elasticio'

cleanup = (logger, client) ->
  logger.debug 'Deleting old inventory entries...'
  client.inventoryEntries.all().fetch()
  .then (result) ->
    Promise.all _.map result.body.results, (e) ->
      client.inventoryEntries.byId(e.id).delete(e.version)
  .then (results) ->
    logger.debug "#{_.size results} deleted."
    Promise.resolve()

describe 'elasticio integration', ->

  beforeEach (done) ->
    @logger = new ExtendedLogger
      additionalFields:
        project_key: Config.config.project_key
      logConfig:
        name: "#{package_json.name}-#{package_json.version}"
        streams: [
          { level: 'info', stream: process.stdout }
        ]
    @client = new SphereClient Config

    @logger.info 'About to setup...'
    cleanup(@logger, @client)
    .then -> done()
    .catch (err) -> done(err)
  , 10000 # 10sec

  afterEach (done) ->
    @logger.info 'About to cleanup...'
    cleanup(@logger, @client)
    .then -> done()
    .catch (err) -> done(err)
  , 10000 # 10sec

  it 'should work with no attachments nor body', (done) ->
    cfg =
      sphereClientId: 'some'
      sphereClientSecret: 'stuff'
      sphereProjectKey: 'here'
    msg = ''
    elasticio.process msg, cfg, (error, message) ->
      expect(error).toBe '[SphereStockImport] No data found in elastic.io msg.'
      done()

  describe 'XML file', ->

    it 'should import from one file with 2 entries', (done) ->
      cfg =
        sphereClientId: Config.config.client_id
        sphereClientSecret: Config.config.client_secret
        sphereProjectKey: Config.config.project_key
      xml =
        '''
        <root>
          <row>
            <code>e-123</code>
            <quantity>-2</quantity>
          </row>
          <row>
            <code>e-xyz</code>
            <quantity>0</quantity>
          </row>
        </root>
        '''
      enc = new Buffer(xml).toString('base64')
      msg =
        attachments:
          'stock.xml':
            content: enc

      spyOn(ElasticIo, 'returnSuccess').andCallThrough()
      elasticio.process msg, cfg, (error, message) ->
        expect(error).toBe null
        if message is '[SphereStockImport] elastic.io messages sent.'
          expect(ElasticIo.returnSuccess.callCount).toBe 3
          expectedMessage =
            body:
              QUANTITY: -2
              SKU: 'e-123'
          expect(ElasticIo.returnSuccess).toHaveBeenCalledWith(expectedMessage, jasmine.any(Function))
          expectedMessage =
            body:
              QUANTITY: 0
              SKU: 'e-xyz'
          expect(ElasticIo.returnSuccess).toHaveBeenCalledWith(expectedMessage, jasmine.any(Function))
          done()

  describe 'CSV file', ->

    it 'should import from one file with 3 entries', (done) ->
      cfg =
        sphereClientId: Config.config.client_id
        sphereClientSecret: Config.config.client_secret
        sphereProjectKey: Config.config.project_key
      csv =
        '''
        sku,quantityOnStock
        c1,1
        c2,2
        c3,3
        '''
      enc = new Buffer(csv).toString('base64')
      msg =
        attachments:
          'stock.csv':
            content: enc

      spyOn(ElasticIo, 'returnSuccess').andCallThrough()
      elasticio.process msg, cfg, (error, message) ->
        expect(error).toBe null
        if message is '[SphereStockImport] elastic.io messages sent.'
          expect(error).toBe null
          expectedMessage =
            body:
              QUANTITY: 1
              SKU: 'c1'
          expect(ElasticIo.returnSuccess).toHaveBeenCalledWith(expectedMessage, jasmine.any(Function))
          expectedMessage =
            body:
              QUANTITY: 2
              SKU: 'c2'
          expect(ElasticIo.returnSuccess).toHaveBeenCalledWith(expectedMessage, jasmine.any(Function))
          expectedMessage =
            body:
              QUANTITY: 3
              SKU: 'c3'
          expect(ElasticIo.returnSuccess).toHaveBeenCalledWith(expectedMessage, jasmine.any(Function))
          done()

  describe 'CSV mapping', ->

    it 'should import a simple entry', (done) ->
      cfg =
        sphereClientId: Config.config.client_id
        sphereClientSecret: Config.config.client_secret
        sphereProjectKey: Config.config.project_key

      msg =
        attachments: {}
        body:
          SKU: 'mySKU1'
          QUANTITY: 7

      elasticio.process msg, cfg, (error, message) ->
        expect(error).toBe null
        expect(message).toBe 'Summary: there were 1 imported stocks (1 were new and 0 were updates)'
        msg.body.QUANTITY = '3'
        elasticio.process msg, cfg, (error, message) ->
          expect(error).toBe null
          expect(message).toBe 'Summary: there were 1 imported stocks (0 were new and 1 were updates)'
          elasticio.process msg, cfg, (error, message) ->
            expect(error).toBe null
            expect(message).toBe 'Summary: nothing to do, everything is fine'
            done()
    , 10000 # 10sec

    it 'should import an entry with channel key', (done) ->
      cfg =
        sphereClientId: Config.config.client_id
        sphereClientSecret: Config.config.client_secret
        sphereProjectKey: Config.config.project_key

      msg =
        attachments: {}
        body:
          SKU: 'mySKU2'
          QUANTITY: -3
          CHANNEL_KEY: 'channel-key-test'

      elasticio.process msg, cfg, (error, message) ->
        expect(error).toBe null
        expect(message).toBe 'Summary: there were 1 imported stocks (1 were new and 0 were updates)'
        msg.body.QUANTITY = '3'
        elasticio.process msg, cfg, (error, message) ->
          expect(error).toBe null
          expect(message).toBe 'Summary: there were 1 imported stocks (0 were new and 1 were updates)'
          done()
    , 10000 # 10sec

    it 'should import an entry with channel id', (done) ->
      cfg =
        sphereClientId: Config.config.client_id
        sphereClientSecret: Config.config.client_secret
        sphereProjectKey: Config.config.project_key

      @client.channels.ensure('channel-id-test', ['InventorySupply', 'OrderExport', 'OrderImport'])
      .then (channel) ->
        msg =
        attachments: {}
        body:
          SKU: 'mySKU3'
          QUANTITY: 99
          CHANNEL_ID: channel.id

        elasticio.process msg, cfg, (error, message) ->
          expect(error).toBe null
          expect(message).toBe 'Summary: there were 1 imported stocks (1 were new and 0 were updates)'
          msg.body.QUANTITY = '3'
          elasticio.process msg, cfg, (error, message) ->
            expect(error).toBe null
            expect(message).toBe 'Summary: there were 1 imported stocks (0 were new and 1 were updates)'
            done()
    , 10000 # 10sec
