Config = require '../config'
StockXmlImport = require('../lib/stockxmlimport').StockXmlImport

describe 'process', ->
  beforeEach (done) ->
    @import = new StockXmlImport Config
    @import.rest.GET "/inventory", (error, response, body) =>
      stocks = JSON.parse(body).results
      if stocks.length is 0
        done()
      for s in stocks
        @import.rest.DELETE "/inventory/#{s.id}", (error, response, body) =>
        done()

  it 'one new stock', (done) ->
    rawXml = '
<row>
  <code>123</code>
  <quantity>2</quantity>
</row>'
    d =
      attachments:
        stock: rawXml
    @import.process d, (msg) =>
      expect(msg.message.status).toBe true
      expect(msg.message.msg).toBe 'New stock created'
      @import.process d, (msg) =>
        expect(msg.message.status).toBe true
        expect(msg.message.msg).toBe 'Stock update not neccessary'
        done()

  xit 'update a stock', (done) ->
    rawXml = '
<row>
  <code>234</code>
  <quantity>0</quantity>
</row>'
    d =
      attachments:
        stock: rawXml
    @import.process d, (msg) =>
      expect(msg.message.status).toBe true
      expect(msg.message.msg).toBe 'New stock created'
      @import.process d, (msg) =>
        expect(msg.message.status).toBe true
        expect(msg.message.msg).toBe 'Stock update not neccessary'
        done()
