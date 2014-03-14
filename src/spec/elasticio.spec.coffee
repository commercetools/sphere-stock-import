_ = require('underscore')._
elasticio = require '../elasticio'
Config = require '../config'
StockXmlImport = require('../main').StockXmlImport

describe 'elasticio XML file integration', ->
  it 'should work with no attachments nor body', (done) ->
    cfg =
      sphereClientId: 'some'
      sphereClientSecret: 'stuff'
      sphereProjectKey: 'here'
    msg = ''
    elasticio.process msg, cfg, (next) ->
      expect(next.status).toBe false
      expect(next.message).toBe 'No data found in elastic.io msg.'
      done()

  it 'should import from one file with 2 entries', (done) ->
    cfg =
      sphereClientId: Config.config.client_id
      sphereClientSecret: Config.config.client_secret
      sphereProjectKey: Config.config.project_key
    xml =
      '''
      <root>
        <row>
          <code>abc</code>
          <quantity>-2</quantity>
        </row>
        <row>
          <code>xyz</code>
          <quantity>0</quantity>
        </row>
      </root>
      '''
    enc = new Buffer(xml).toString('base64')
    msg =
      attachments:
        'stock.xml':
          content: enc

    elasticio.process msg, cfg, (next) ->
      expect(next.status).toBe true
      expect(_.size next.message).toBe 1
      expect(next.message['New inventory entry created.']).toBe 2
      done()

describe 'elasticio CSV mapping integration', ->
  it 'should import a simple entry', (done) ->
    cfg =
      sphereClientId: Config.config.client_id
      sphereClientSecret: Config.config.client_secret
      sphereProjectKey: Config.config.project_key

    msg =
      attachments: {}
      body:
        SKU: 'mySKU'
        QUANTITY: 7

    elasticio.process msg, cfg, (next) ->
      expect(next.status).toBe true
      expect(next.message).toBe 'New inventory entry created.'
      msg.body.QUANTITY = '3'
      elasticio.process msg, cfg, (next) ->
        expect(next.status).toBe true
        expect(next.message).toBe 'Inventory entry updated.'
        elasticio.process msg, cfg, (next) ->
          expect(next.status).toBe true
          expect(next.message).toBe 'Inventory entry update not neccessary.'
          done()

  it 'should import an entry with channel key', (done) ->
    cfg =
      sphereClientId: Config.config.client_id
      sphereClientSecret: Config.config.client_secret
      sphereProjectKey: Config.config.project_key

    msg =
      attachments: {}
      body:
        SKU: 'mySKU'
        QUANTITY: -3
        CHANNEL_KEY: 'channel-key-test'

    elasticio.process msg, cfg, (next) ->
      expect(next.status).toBe true
      expect(next.message).toBe 'New inventory entry created.'
      msg.body.QUANTITY = '3'
      elasticio.process msg, cfg, (next) ->
        expect(next.status).toBe true
        expect(next.message).toBe 'Inventory entry updated.'
        done()

  it 'should import an entry with channel id', (done) ->
    cfg =
      sphereClientId: Config.config.client_id
      sphereClientSecret: Config.config.client_secret
      sphereProjectKey: Config.config.project_key

    sxi = new StockXmlImport Config
    sxi.ensureChannelByKey(sxi.rest, 'channel-id-test').then (channel) ->
      msg =
      attachments: {}
      body:
        SKU: 'mySKU'
        QUANTITY: 99
        CHANNEL_ID: channel.id

      elasticio.process msg, cfg, (next) ->
        expect(next.status).toBe true
        expect(next.message).toBe 'New inventory entry created.'
        msg.body.QUANTITY = '3'
        elasticio.process msg, cfg, (next) ->
          expect(next.status).toBe true
          expect(next.message).toBe 'Inventory entry updated.'
          done()