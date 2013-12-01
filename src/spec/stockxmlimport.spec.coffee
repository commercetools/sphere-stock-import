Config = require '../config'
StockXmlImport = require('../lib/stockxmlimport').StockXmlImport

describe 'StockXmlImport', ->
  beforeEach ->
    @import = new StockXmlImport('foo')

  it 'should initialize', ->
    expect(@import).toBeDefined()

  it 'should initialize with options', ->
    expect(@import._options).toBe 'foo'


describe 'process', ->
  beforeEach ->
    @import = new StockXmlImport()

  it 'should throw error if no JSON object is passed', ->
    expect(@import.process).toThrow new Error('JSON Object required')

  it 'should throw error if no JSON object is passed', ->
    expect(=> @import.process({})).toThrow new Error('Callback must be a function')

  it 'should call the given callback and return messge', (done) ->
    @import.process {}, (data)->
      expect(data.message.status).toBe false
      expect(data.message.msg).toBe 'No XML data attachments found.'
      done()

describe 'transform', ->
  beforeEach ->
    @import = new StockXmlImport Config

  it 'single attachment - one entry', (done) ->
    rawXml = '
<row>
  <code>123</code>
  <quantity>2</quantity>
</row>'

    @import.transform @import.getAndFix(rawXml), (stocks) ->
      expect(stocks.length).toBe 1
      s = stocks[0]
      expect(s.sku).toBe '123'
      expect(s.quantityOnStock).toBe 2
      done()