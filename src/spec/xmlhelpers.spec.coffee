xmlHelpers = require '../lib/xmlhelpers.js'

describe "xmlEncodeAndFix", ->
  it "adds xml header", ->
    input = "<root>val</root>"
    base64 = new Buffer(input).toString('base64')
    expect(xmlHelpers.xmlEncodeAndFix(base64))
      .toBe '<?xml version=\"1.0\" encoding=\"UTF-8\"?><root>val</root>'

  it "adds root element", ->
    input = "<row>1</row><row>2</row>"
    base64 = new Buffer(input).toString('base64')
    expect(xmlHelpers.xmlEncodeAndFix(base64))
      .toBe '<?xml version=\"1.0\" encoding=\"UTF-8\"?><root><row>1</row><row>2</row></root>'

describe "xmlTransform", ->
  it "works", ->
    xml = "<root><row><id>1</id></row><row><id>2</id></row></root>"
    xmlHelpers.xmlTransform xml, (err, result) =>
      expect(err).toBeNull()
      e =
        root:
          row: [
            { id: [ '1' ] }
            { id: [ '2' ] }
          ]
      expect(result).toEqual e

describe "xmlVal", ->
  it "works", ->
    xml = "<root><row><id>foo</id></row></root>"
    xmlHelpers.xmlTransform xml, (err, result) =>
      expect(xmlHelpers.xmlVal(result.root.row[0], 'id')).toBe 'foo'
      expect(xmlHelpers.xmlVal(result.root.row[0], 'bar', 'default')).toBe 'default'