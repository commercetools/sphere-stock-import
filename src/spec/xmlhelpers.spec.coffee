xmlHelpers = require '../lib/xmlhelpers.js'

describe 'xmlHelpers', ->

  describe "#xmlFix", ->
    it "adds xml header", ->
      input = "<root>val</root>"
      expect(xmlHelpers.xmlFix(input))
        .toBe '<?xml version=\"1.0\" encoding=\"UTF-8\"?><root>val</root>'

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

    it "gives feedback on xml error", ->
      xml = "<root><root>"
      xmlHelpers.xmlTransform xml, (err, result) ->
        expect(err).toMatch /Error/

  describe "#xmlVal", ->
    it "works", ->
      xml = "<root><row><code>foo</code>123</row></root>"
      xmlHelpers.xmlTransform xml, (err, result) ->
        expect(xmlHelpers.xmlVal(result.root.row[0], 'code')).toBe 'foo'
        expect(result.root.row[0]['_']).toBe '123'
        expect(xmlHelpers.xmlVal(result.root.row[0], 'foo', 'defaultValue')).toBe 'defaultValue'
