constants =
  HEADER_SKU: 'sku'
  HEADER_QUANTITY: 'quantityOnStock'
  DEPRECATED_HEADER_QUANTITY: 'quantity'
  HEADER_RESTOCKABLE: 'restockableInDays'
  HEADER_EXPECTED_DELIVERY: 'expectedDelivery'
  HEADER_SUPPLY_CHANNEL: 'supplyChannel'
  HEADER_CUSTOM_TYPE: 'customType'
  HEADER_CUSTOM_SEPERATOR: '.'
  HEADER_CUSTOM_REGEX: new RegExp /^customField\./

  CHANNEL_KEY_FOR_XML_MAPPING: 'expectedStock'
  CHANNEL_REF_NAME: 'supplyChannel'
  CHANNEL_ROLES: ['InventorySupply', 'OrderExport', 'OrderImport']
  LOG_PREFIX: "[SphereStockImport] "
  CHANNEL_REFERENCE_TYPE: 'channel'

  REGEX_PRICE: new RegExp /^(([A-Za-z]{2})-|)([A-Z]{3}) (-?\d+)(-?\|(\d+)|)( ([^#]*)|)(#(.*)|)$/
  REGEX_MONEY: new RegExp /^([A-Z]{3}) (-?\d+)$/
  REGEX_INTEGER: new RegExp /^-?\d+$/
  REGEX_FLOAT: new RegExp /^-?\d+(\.\d+)?$/
  REGEX_LANGUAGE: new RegExp /^([a-z]{2,3}(?:-[A-Z]{2,3}(?:-[a-zA-Z]{4})?)?)$/


for name, value of constants
  exports[name] = value
