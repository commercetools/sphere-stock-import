_ = require('underscore')._
elasticio = require('../elasticio.js')
Config = require '../config'

describe "elasticio file integration", ->
  it "with no attachments nor body", (done) ->
    cfg =
      clientId: 'some'
      clientSecret: 'stuff'
      projectKey: 'here'
    msg = ''
    elasticio.process msg, cfg, (next) ->
      expect(next.status).toBe false
      expect(next.message).toBe 'No data found in elastic.io msg.'
      done()

  it "single attachment - 2 entries", (done) ->
    cfg =
      clientId: Config.config.client_id
      clientSecret: Config.config.client_secret
      projectKey: Config.config.project_key
    xml = '
<row>
  <code>abc</code>
  <quantity>-2</quantity>
</row>
<row>
  <code>xyz</code>
  <quantity>0</quantity>
</row>
'
    enc = new Buffer(xml).toString('base64')
    msg =
      attachments:
        'stock.xml':
          content: enc

    elasticio.process msg, cfg, (next) ->
      expect(next.status).toBe true
      expect(_.size(next.message)).toBe 1
      expect(next.message['New inventory entry created.']).toBe 2
      done()

describe "elasticio mapping integration", ->
  it "single entry", (done) ->
    cfg =
      clientId: Config.config.client_id
      clientSecret: Config.config.client_secret
      projectKey: Config.config.project_key

    msg =
      body:
        SKU: 'mySKU'
        QUANTITY: 7

    elasticio.process msg, cfg, (next) ->
      expect(next.status).toBe true
      expect(next.message).toBe 'New inventory entry created.'
      msg.body.QUANTITY = 3
      elasticio.process msg, cfg, (next) ->
        expect(next.status).toBe true
        expect(next.message).toBe 'Inventory entry updated.'
        done()