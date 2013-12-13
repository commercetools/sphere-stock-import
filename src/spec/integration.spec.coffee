Config = require '../config'
StockXmlImport = require('../main').StockXmlImport
Q = require('q')

# Increase timeout
jasmine.getEnv().defaultTimeoutInterval = 20000

describe '#run', ->
  beforeEach (done) ->
    @import = new StockXmlImport Config

    del = (id) =>
      deferred = Q.defer()
      @import.rest.DELETE "/inventory/#{id}", (error, response, body) ->
        if error
          deferred.reject error
        else
          if response.statusCode is 200 or response.statusCode is 404
            deferred.resolve true
          else
            deferred.reject body
      deferred.promise

    @import.rest.GET "/inventory?limit=0", (error, response, body) ->
      stocks = JSON.parse(body).results
      if stocks.length is 0
        done()
      console.log "Cleaning up stock entries: " + stocks.length
      dels = []
      for s in stocks
        dels.push del(s.id)

      Q.allSettled(dels).then (v) ->
        done()
      .fail (err) ->
        throw new Error "Problems on deleting old entires in beforeEach"

  it 'Nothing to do', (done) ->
    @import.run "<bar></bar>", (msg) ->
      expect(msg.message.status).toBe true
      expect(msg.message.msg).toBe '0 Done'
      done()

  it 'one new stock', (done) ->
    rawXml = '
<row>
  <code>123</code>
  <quantity>2</quantity>
</row>'
    @import.run rawXml, (msg) =>
      expect(msg.message.status).toBe true
      expect(msg.message.msg).toBe 'New stock created'
      @import.rest.GET "/inventory", (error, response, body) =>
        stocks = JSON.parse(body).results
        expect(stocks.length).toBe 1
        expect(stocks[0].sku).toBe '123'
        expect(stocks[0].quantityOnStock).toBe 2
        @import.run rawXml, (msg) =>
          expect(msg.message.status).toBe true
          expect(msg.message.msg).toBe 'Stock update not neccessary'
          @import.rest.GET "/inventory", (error, response, body) ->
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
    rawXmlChanged = rawXml.replace('7', '19')
    @import.run rawXml, (msg) =>
      expect(msg.message.status).toBe true
      expect(msg.message.msg).toBe 'New stock created'
      @import.rest.GET "/inventory", (error, response, body) =>
        stocks = JSON.parse(body).results
        expect(stocks.length).toBe 1
        expect(stocks[0].sku).toBe '234'
        expect(stocks[0].quantityOnStock).toBe 7
        @import.run rawXmlChanged, (msg) =>
          expect(msg.message.status).toBe true
          expect(msg.message.msg).toBe 'Stock updated'
          @import.rest.GET "/inventory", (error, response, body) ->
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
    rawXmlChanged = rawXml.replace('77', '13')
    @import.run rawXml, (msg) =>
      expect(msg.message.status).toBe true
      expect(msg.message.msg).toBe 'New stock created'
      @import.rest.GET "/inventory", (error, response, body) =>
        stocks = JSON.parse(body).results
        expect(stocks.length).toBe 1
        expect(stocks[0].sku).toBe '1234567890'
        expect(stocks[0].quantityOnStock).toBe 77
        @import.run rawXmlChanged, (msg) =>
          expect(msg.message.status).toBe true
          expect(msg.message.msg).toBe 'Stock updated'
          @import.rest.GET "/inventory", (error, response, body) ->
            stocks = JSON.parse(body).results
            expect(stocks.length).toBe 1
            expect(stocks[0].sku).toBe '1234567890'
            expect(stocks[0].quantityOnStock).toBe 13
            done()