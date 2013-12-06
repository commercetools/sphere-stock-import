{parseString} = require 'xml2js'

exports.xmlEncodeAndFix = (raw) ->
  xml = new Buffer(raw, 'base64').toString()
  if not xml.match /<root>.*<\/root>/
    xml = "<root>#{xml}</root>"
  if not xml.match /\?xml/
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>#{xml}"

exports.xmlTransform = (xml, callback) ->
  parseString xml, callback

exports.xmlVal = (elem, attribName, fallback) ->
  return elem[attribName][0] if elem[attribName]
  fallback