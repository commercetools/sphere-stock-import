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


describe 'run', ->
  beforeEach ->
    @import = new StockXmlImport()

  it 'should throw error if no JSON object is passed', ->
    expect(@import.run).toThrow new Error('String required')

  it 'should throw error if no JSON object is passed', ->
    expect(=> @import.run("")).toThrow new Error('Callback must be a function')

  it 'should call the given callback and return messge', (done) ->
    @import.run "", (data)->
      expect(data.message.status).toBe true
      expect(data.message.msg).toBe '0 Done'
      done()

describe 'transform', ->
  beforeEach ->
    @import = new StockXmlImport Config

  it 'one entry', (done) ->
    rawXml = '
<row>
  <code>123</code>
  <quantity>2</quantity>
</row>'

    xml = xmlHelpers.xmlFix(rawXml)
    xmlHelpers.xmlTransform xml, (err, result) =>
      stocks = @import.mapStock result.root
      expect(stocks.length).toBe 1
      s = stocks[0]
      expect(s.sku).toBe '123'
      expect(s.quantityOnStock).toBe 2
      done()