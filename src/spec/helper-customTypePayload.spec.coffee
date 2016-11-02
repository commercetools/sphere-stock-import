baseObj = {
  "key": "my-type",
  "name": { "en": "customized fields" },
  "description": { "en": "customized fields definition" },
  "resourceTypeIds": ["inventory-entry"],
  "fieldDefinitions": [
    {
      "name": "description",
      "type": { "name": "String" },
      "required": false,
      "label": { "en": "size" },
      "inputHint": "SingleLine"
    },
    {
      "name": "color",
      "type": {"name": "String"},
      "required": false,
      "label": { "en": "color" },
      "inputHint": "SingleLine"
    },
    {
      "name": "quantityFactor",
      "type": {"name": "Number"},
      "required": false,
      "label": { "en": "quantityFactor" },
      "inputHint": "SingleLine"
    },
    {
      "name": "price",
      "type": {"name": "Money"},
      "required": false,
      "label": { "en": "price" },
      "inputHint": "SingleLine"
    },
    {
      "name": "localizedString",
      "type": { "name": "LocalizedString" },
      "required": false,
      "label": { "en": "size" },
      "inputHint": "SingleLine"
    },
    {
      "name": "name",
      "type": { "name": "LocalizedString" },
      "required": false,
      "label": { "en": "name" },
      "inputHint": "SingleLine"
    }
  ]
}

exports.customTypePayload1 = ->
  JSON.parse(JSON.stringify(baseObj))
exports.customTypePayload2 = ->
  data = JSON.parse(JSON.stringify(baseObj))
  data.key = "my-type1"
  data
exports.customTypePayload3 = ->
  data = JSON.parse(JSON.stringify(baseObj))
  data.key = "my-type2"
  data.fieldDefinitions[1] =
    "name": "another",
    "type": { "name": "String" },
    "required": false,
    "label": { "en": "size" },
    "inputHint": "SingleLine"
  data
