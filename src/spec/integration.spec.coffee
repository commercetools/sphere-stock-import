_ = require('underscore')._
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

    @import.rest.GET '/inventory?limit=0', (error, response, body) ->
      stocks = JSON.parse(body).results
      if stocks.length is 0
        done()
      console.log "Cleaning up #{stocks.length} inventory entries."
      dels = []
      for s in stocks
        dels.push del(s.id)

      Q.all(dels).then (v) ->
        done()
      .fail (err) ->
        console.log err
        done()

  it 'Nothing to do', (done) ->
    @import.run '<root></root>', (msg) ->
      expect(msg.status).toBe true
      expect(msg.message).toBe 'Nothing to do.'
      done()

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
    @import.run rawXml, (msg) =>
      expect(msg.status).toBe true
      expect(msg.message).toBe 'New inventory entry created.'
      @import.rest.GET '/inventory', (error, response, body) =>
        stocks = JSON.parse(body).results
        expect(stocks.length).toBe 1
        expect(stocks[0].sku).toBe '123'
        expect(stocks[0].quantityOnStock).toBe 2
        @import.run rawXml, (msg) =>
          expect(msg.status).toBe true
          expect(msg.message).toBe 'Inventory entry update not neccessary.'
          @import.rest.GET '/inventory', (error, response, body) ->
            stocks = JSON.parse(body).results
            expect(stocks.length).toBe 1
            expect(stocks[0].sku).toBe '123'
            expect(stocks[0].quantityOnStock).toBe 2
            done()

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
    @import.run rawXml, (msg) =>
      expect(msg.status).toBe true
      expect(msg.message).toBe 'New inventory entry created.'
      @import.rest.GET '/inventory', (error, response, body) =>
        stocks = JSON.parse(body).results
        expect(stocks.length).toBe 1
        expect(stocks[0].sku).toBe '234'
        expect(stocks[0].quantityOnStock).toBe 7
        @import.run rawXmlChanged, (msg) =>
          expect(msg.status).toBe true
          expect(msg.message).toBe 'Inventory entry updated.'
          @import.rest.GET '/inventory', (error, response, body) ->
            stocks = JSON.parse(body).results
            expect(stocks.length).toBe 1
            expect(stocks[0].sku).toBe '234'
            expect(stocks[0].quantityOnStock).toBe 19
            done()

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
    rawXmlChanged = rawXml.replace('77', '13')
    @import.run rawXml, (msg) =>
      expect(msg.status).toBe true
      expect(msg.message).toBe 'New inventory entry created.'
      @import.rest.GET '/inventory', (error, response, body) =>
        stocks = JSON.parse(body).results
        expect(stocks.length).toBe 1
        expect(stocks[0].sku).toBe '1234567890'
        expect(stocks[0].quantityOnStock).toBe 77
        @import.run rawXmlChanged, (msg) =>
          expect(msg.status).toBe true
          expect(msg.message).toBe 'Inventory entry updated.'
          @import.rest.GET '/inventory', (error, response, body) ->
            stocks = JSON.parse(body).results
            expect(stocks.length).toBe 1
            expect(stocks[0].sku).toBe '1234567890'
            expect(stocks[0].quantityOnStock).toBe 13
            done()

  it 'should create and update 2 stock entries when appointed quantity is given', (done) ->
    rawXml =
      '''
      <root>
        <row>
          <code>myEAN</code>
          <quantity>-1</quantity>
          <AppointedQuantity>10</AppointedQuantity>
          <CommittedDeliveryDate>1999-12-31T11:11:11.000Z</CommittedDeliveryDate>
        </row>
      </root>
      '''
    rawXmlChangedAppointedQuantity = rawXml.replace('10', '20')
    rawXmlChangedCommittedDeliveryDate = rawXml.replace('1999-12-31T11:11:11.000Z', '2000-01-01T12:12:12.000Z')

    @import.run rawXml, (msg) =>
      expect(msg.status).toBe true
      expect(_.size msg.message).toBe 1
      expect(msg.message['New inventory entry created.']).toBe 2
      @import.rest.GET '/inventory', (error, response, body) =>
        stocks = JSON.parse(body).results
        expect(stocks.length).toBe 2
        expect(stocks[0].sku).toBe 'myEAN'
        expect(stocks[0].quantityOnStock).toBe -1
        expect(stocks[0].supplyChannel).toBeUndefined()
        expect(stocks[1].sku).toBe 'myEAN'
        expect(stocks[1].quantityOnStock).toBe 10
        expect(stocks[1].supplyChannel).toBeDefined()
        expect(stocks[1].expectedDelivery).toBe '1999-12-31T11:11:11.000Z'

        @import.run rawXmlChangedAppointedQuantity, (msg) =>
          expect(msg.status).toBe true
          expect(_.size msg.message).toBe 2
          expect(msg.message['Inventory entry updated.']).toBe 1
          expect(msg.message['Inventory entry update not neccessary.']).toBe 1
          @import.rest.GET '/inventory', (error, response, body) =>
            stocks = JSON.parse(body).results
            expect(stocks[0].sku).toBe 'myEAN'
            expect(stocks[0].quantityOnStock).toBe -1
            expect(stocks[0].supplyChannel).toBeUndefined()
            expect(stocks[1].sku).toBe 'myEAN'
            expect(stocks[1].quantityOnStock).toBe 20
            expect(stocks[1].supplyChannel).toBeDefined()
            expect(stocks[1].expectedDelivery).toBe '1999-12-31T11:11:11.000Z'

            @import.run rawXmlChangedCommittedDeliveryDate, (msg) =>
              expect(msg.status).toBe true
              expect(_.size msg.message).toBe 2
              expect(msg.message['Inventory entry updated.']).toBe 1
              expect(msg.message['Inventory entry update not neccessary.']).toBe 1
              @import.rest.GET '/inventory', (error, response, body) =>
                stocks = JSON.parse(body).results
                expect(stocks[0].sku).toBe 'myEAN'
                expect(stocks[0].quantityOnStock).toBe -1
                expect(stocks[0].supplyChannel).toBeUndefined()
                expect(stocks[1].sku).toBe 'myEAN'
                expect(stocks[1].quantityOnStock).toBe 10
                expect(stocks[1].supplyChannel).toBeDefined()
                expect(stocks[1].expectedDelivery).toBe '2000-01-01T12:12:12.000Z'

                @import.run rawXmlChangedCommittedDeliveryDate, (msg) =>
                  expect(msg.status).toBe true
                  expect(_.size msg.message).toBe 1
                  expect(msg.message['Inventory entry update not neccessary.']).toBe 2
                  @import.rest.GET '/inventory', (error, response, body) ->
                    stocks = JSON.parse(body).results
                    expect(stocks[0].sku).toBe 'myEAN'
                    expect(stocks[0].quantityOnStock).toBe -1
                    expect(stocks[0].supplyChannel).toBeUndefined()
                    expect(stocks[1].sku).toBe 'myEAN'
                    expect(stocks[1].quantityOnStock).toBe 10
                    expect(stocks[1].supplyChannel).toBeDefined()
                    expect(stocks[1].expectedDelivery).toBe '2000-01-01T12:12:12.000Z'

                    done()