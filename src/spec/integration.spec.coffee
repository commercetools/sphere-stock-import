Config = require '../config'
StockXmlImport = require('../lib/stockxmlimport').StockXmlImport

# Increase timeout
jasmine.getEnv().defaultTimeoutInterval = 20000

describe 'process', ->
  beforeEach (done) ->
    @import = new StockXmlImport Config
    @import.rest.GET "/inventory", (error, response, body) =>
      stocks = JSON.parse(body).results
      if stocks.length is 0
        done()
      for s in stocks
        @import.rest.DELETE "/inventory/#{s.id}", (error, response, body) =>
          expect(response.statusCode).toMatch /[24]0[04]/
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
      @import.rest.GET "/inventory", (error, response, body) =>
        stocks = JSON.parse(body).results
        expect(stocks.length).toBe 1
        expect(stocks[0].sku).toBe '123'
        expect(stocks[0].quantityOnStock).toBe 2
        @import.process d, (msg) =>
          expect(msg.message.status).toBe true
          expect(msg.message.msg).toBe 'Stock update not neccessary'
          @import.rest.GET "/inventory", (error, response, body) =>
            stocks = JSON.parse(body).results
            expect(stocks.length).toBe 1
            expect(stocks[0].sku).toBe '123'
            expect(stocks[0].quantityOnStock).toBe 2
            done()

  it 'add more stock', (done) ->
    rawXml = '
<row>
  <code>234</code>
  <quantity>7</quantity>
</row>'
    d =
      attachments:
        stock: rawXml
    d2 =
      attachments:
        stock: rawXml.replace '7', '19'
    @import.process d, (msg) =>
      expect(msg.message.status).toBe true
      expect(msg.message.msg).toBe 'New stock created'
      @import.rest.GET "/inventory", (error, response, body) =>
        stocks = JSON.parse(body).results
        expect(stocks.length).toBe 1
        expect(stocks[0].sku).toBe '234'
        expect(stocks[0].quantityOnStock).toBe 7
        @import.process d2, (msg) =>
          expect(msg.message.status).toBe true
          expect(msg.message.msg).toBe 'Stock updated'
          @import.rest.GET "/inventory", (error, response, body) =>
            stocks = JSON.parse(body).results
            expect(stocks.length).toBe 1
            expect(stocks[0].sku).toBe '234'
            expect(stocks[0].quantityOnStock).toBe 19
            done()

  it 'remove some stock', (done) ->
    rawXml = '
<row>
  <code>1234567890</code>
  <quantity>77</quantity>
</row>'
    d =
      attachments:
        stock: rawXml
    d2 =
      attachments:
        stock: rawXml.replace '77', '13'
    @import.process d, (msg) =>
      expect(msg.message.status).toBe true
      expect(msg.message.msg).toBe 'New stock created'
      @import.rest.GET "/inventory", (error, response, body) =>
        stocks = JSON.parse(body).results
        expect(stocks.length).toBe 1
        expect(stocks[0].sku).toBe '1234567890'
        expect(stocks[0].quantityOnStock).toBe 77
        @import.process d2, (msg) =>
          expect(msg.message.status).toBe true
          expect(msg.message.msg).toBe 'Stock updated'
          @import.rest.GET "/inventory", (error, response, body) =>
            stocks = JSON.parse(body).results
            expect(stocks.length).toBe 1
            expect(stocks[0].sku).toBe '1234567890'
            expect(stocks[0].quantityOnStock).toBe 13
            done()