_ = require 'underscore'
elasticio = require '../lib/elasticio'
Config = require '../config'
StockImport = require '../lib/stockimport'
{ElasticIo} = require 'sphere-node-utils'

describe 'elasticio integration', ->
  it 'should work with no attachments nor body', (done) ->
    cfg =
      sphereClientId: 'some'
      sphereClientSecret: 'stuff'
      sphereProjectKey: 'here'
    msg = ''
    elasticio.process msg, cfg, (error, message) ->
      expect(error).toBe 'No data found in elastic.io msg.'
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
        if message is 'elastic.io messages sent.'
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
        sku,quantity
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
        if message is 'elastic.io messages sent.'
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
        expect(message['Inventory entry created.']).toBe 1
        expect(message['Inventory entry updated.']).toBe 0
        expect(message['Inventory update was not necessary.']).toBe 0
        msg.body.QUANTITY = '3'
        elasticio.process msg, cfg, (error, message) ->
          expect(error).toBe null
          expect(message['Inventory entry created.']).toBe 0
          expect(message['Inventory entry updated.']).toBe 1
          expect(message['Inventory update was not necessary.']).toBe 0
          elasticio.process msg, cfg, (error, message) ->
            expect(error).toBe null
            expect(message['Inventory entry created.']).toBe 0
            expect(message['Inventory entry updated.']).toBe 0
            expect(message['Inventory update was not necessary.']).toBe 1
            done()

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
        expect(message['Inventory entry created.']).toBe 1
        expect(message['Inventory entry updated.']).toBe 0
        expect(message['Inventory update was not necessary.']).toBe 0
        msg.body.QUANTITY = '3'
        elasticio.process msg, cfg, (error, message) ->
          expect(error).toBe null
          expect(message['Inventory entry created.']).toBe 0
          expect(message['Inventory entry updated.']).toBe 1
          expect(message['Inventory update was not necessary.']).toBe 0
          done()

    it 'should import an entry with channel id', (done) ->
      cfg =
        sphereClientId: Config.config.client_id
        sphereClientSecret: Config.config.client_secret
        sphereProjectKey: Config.config.project_key

      sxi = new StockImport Config
      sxi.ensureChannelByKey(sxi.client._rest, 'channel-id-test').then (channel) ->
        msg =
        attachments: {}
        body:
          SKU: 'mySKU3'
          QUANTITY: 99
          CHANNEL_ID: channel.id

        elasticio.process msg, cfg, (error, message) ->
          expect(error).toBe null
          expect(message['Inventory entry created.']).toBe 1
          expect(message['Inventory entry updated.']).toBe 0
          expect(message['Inventory update was not necessary.']).toBe 0
          msg.body.QUANTITY = '3'
          elasticio.process msg, cfg, (error, message) ->
            expect(error).toBe null
            expect(message['Inventory entry created.']).toBe 0
            expect(message['Inventory entry updated.']).toBe 1
            expect(message['Inventory update was not necessary.']).toBe 0
            done()