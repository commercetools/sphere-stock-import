{parseString} = require 'xml2js'

exports.xmlFix = (xml) ->
  if not xml.match /\<root\>/
    xml = "<root>#{xml}</root>"
  if not xml.match /\?xml/
    xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>#{xml}"
  xml

exports.xmlTransform = (xml, callback) ->
  parseString xml, callback

exports.xmlVal = (elem, attribName, fallback) ->
  return elem[attribName][0] if elem[attribName]
  fallback