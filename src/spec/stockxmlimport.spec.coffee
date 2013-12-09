Config = require '../config'
xmlHelpers = require '../lib/xmlhelpers.js'
StockXmlImport = require('../lib/stockxmlimport').StockXmlImport

describe 'StockXmlImport', ->
  beforeEach ->
    @import = new StockXmlImport('foo')

  it 'should initialize', ->
    expect(@import).toBeDefined()

  it 'should initialize with options', ->
    expect(@import._options).toBe 'foo'


describe '#run', ->
  beforeEach ->
    @import = new StockXmlImport()

  it 'should throw error if no JSON object is passed', ->
    expect(@import.run).toThrow new Error('String required')

  it 'should throw error if no JSON object is passed', ->
    expect(=> @import.run("")).toThrow new Error('Callback must be a function')

  it 'should give feedback on xml parse problems', (done) ->
    @import.run "<<", (data) ->
      expect(data.message.status).toBe false
      expect(data.message.msg).toMatch /Error on parsing XML/
      done()

  xit 'should call the given callback and return messge', (done) ->
    @import.run "<bar></bar>", (data) ->
      expect(data.message.status).toBe true
      expect(data.message.msg).toBe '0 Done'
      done()

describe '#transform', ->
  beforeEach ->
    @import = new StockXmlImport Config

  it 'simple entry', (done) ->
    rawXml = '
<row>
  <code>1</code>
  <quantity>2</quantity>
</row>'

    xml = xmlHelpers.xmlFix(rawXml)
    xmlHelpers.xmlTransform xml, (err, result) =>
      stocks = @import.mapStock result.root
      expect(stocks.length).toBe 1
      s = stocks[0]
      expect(s.sku).toBe '1'
      expect(s.quantityOnStock).toBe 2
      done()

  it 'should map delivery date', (done) ->
    rawXml = '
<row>
  <code>2</code>
  <quantity>7.000</quantity>
  <CommittedDeliveryDate>2013-11-19T00:00:00</CommittedDeliveryDate>
</row>'

    xml = xmlHelpers.xmlFix(rawXml)
    xmlHelpers.xmlTransform xml, (err, result) =>
      stocks = @import.mapStock result.root
      expect(stocks.length).toBe 1
      s = stocks[0]
      expect(s.sku).toBe '2'
      expect(s.quantityOnStock).toBe 7
      expect(s.expectedDelivery).toBe '2013-11-19T00:00:00'
      done()