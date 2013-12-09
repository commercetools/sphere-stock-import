xmlHelpers = require '../lib/xmlhelpers.js'

describe "#xmlFix", ->
  it "adds xml header", ->
    input = "<root>val</root>"
    expect(xmlHelpers.xmlFix(input))
      .toBe '<?xml version=\"1.0\" encoding=\"UTF-8\"?><root>val</root>'

  it "adds root element", ->
    input = "<row>1</row><row>2</row>"
    expect(xmlHelpers.xmlFix(input))
      .toBe '<?xml version=\"1.0\" encoding=\"UTF-8\"?><root><row>1</row><row>2</row></root>'

describe "#xmlTransform", ->
  it "works", ->
    xml = "<root><row><id>1</id></row><row><id>2</id></row></root>"
    xmlHelpers.xmlTransform xml, (err, result) ->
      expect(err).toBeNull()
      e =
        root:
          row: [
            { id: [ '1' ] }
            { id: [ '2' ] }
          ]
      expect(result).toEqual e

describe "#xmlVal", ->
  it "works", ->
    xml = "<root><row><id>foo</id></row></root>"
    xmlHelpers.xmlTransform xml, (err, result) ->
      expect(xmlHelpers.xmlVal(result.root.row[0], 'id')).toBe 'foo'
      expect(xmlHelpers.xmlVal(result.root.row[0], 'bar', 'default')).toBe 'default'
