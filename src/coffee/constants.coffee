constants =
  HEADER_PRODUCT_TYPE: 'productType'
  HEADER_ID: 'id'
  HEADER_EXTERNAL_ID: 'externalId'
  HEADER_VARIANT_ID: 'variantId'

  HEADER_NAME: 'name'
  HEADER_DESCRIPTION: 'description'
  HEADER_CATEGORY_ORDER_HINTS: 'categoryOrderHints'
  HEADER_SLUG: 'slug'

  HEADER_META_TITLE: 'metaTitle'
  HEADER_META_DESCRIPTION: 'metaDescription'
  HEADER_META_KEYWORDS: 'metaKeywords'
  HEADER_SEARCH_KEYWORDS: 'searchKeywords'

  HEADER_TAX: 'tax'
  HEADER_CATEGORIES: 'categories'

  HEADER_SKU: 'sku'
  HEADER_PRICES: 'prices'
  HEADER_IMAGES: 'images'
  HEADER_IMAGE_LABELS: 'imageLabels'
  HEADER_IMAGE_DIMENSIONS: 'imageDimensions'
  HEADER_QUANTITY: 'quantityOnStock'
  HEADER_CUSTOM_TYPE: 'customType'
  HEADER_CUSTOM_SEPERATOR: '.'
  HEADER_CUSTOM_REGEX: new RegExp /^customField\./

  HEADER_PUBLISHED: '_published'
  HEADER_HAS_STAGED_CHANGES: '_hasStagedChanges'
  HEADER_CREATED_AT: '_createdAt'
  HEADER_LAST_MODIFIED_AT: '_lastModifiedAt'

  CHANNEL_KEY_FOR_XML_MAPPING: 'expectedStock'
  CHANNEL_REF_NAME: 'supplyChannel'
  CHANNEL_ROLES: ['InventorySupply', 'OrderExport', 'OrderImport']
  LOG_PREFIX: "[SphereStockImport] "

  ATTRIBUTE_TYPE_SET: 'set'
  ATTRIBUTE_TYPE_LTEXT: 'ltext'
  ATTRIBUTE_TYPE_ENUM: 'enum'
  ATTRIBUTE_TYPE_LENUM: 'lenum'
  ATTRIBUTE_TYPE_NUMBER: 'number'
  ATTRIBUTE_TYPE_MONEY: 'money'
  ATTRIBUTE_TYPE_REFERENCE: 'reference'
  ATTRIBUTE_TYPE_BOOLEAN: 'boolean'

  ATTRIBUTE_CONSTRAINT_SAME_FOR_ALL: 'SameForAll'

  REGEX_PRICE: new RegExp /^(([A-Za-z]{2})-|)([A-Z]{3}) (-?\d+)(-?\|(\d+)|)( ([^#]*)|)(#(.*)|)$/
  REGEX_MONEY: new RegExp /^([A-Z]{3}) (-?\d+)$/
  REGEX_INTEGER: new RegExp /^-?\d+$/
  REGEX_FLOAT: new RegExp /^-?\d+(\.\d+)?$/
  REGEX_LANGUAGE: new RegExp /^(.+)\.([a-z]{2,3}(?:-[A-Z]{2,3}(?:-[a-zA-Z]{4})?)?)$/
  REGEX_CUR: new RegExp /^AED|AFN|ALL|AMD|ANG|AOA|ARS|AUD|AWG|AZN|BAM|BBD|BDT|BGN|BHD|BIF|BMD|BND|BOB|BRL|BSD|BTN|BWP|BYR|BZD|CAD|CDF|CHF|CLP|CNY|COP|CRC|CUC|CUP|CVE|CZK|DJF|DKK|DOP|DZD|EGP|ERN|ETB|EUR|FJD|FKP|GBP|GEL|GGP|GHS|GIP|GMD|GNF|GTQ|GYD|HKD|HNL|HRK|HTG|HUF|IDR|ILS|IMP|INR|IQD|IRR|ISK|JEP|JMD|JOD|JPY|KES|KGS|KHR|KMF|KPW|KRW|KWD|KYD|KZT|LAK|LBP|LKR|LRD|LSL|LYD|MAD|MDL|MGA|MKD|MMK|MNT|MOP|MRO|MUR|MVR|MWK|MXN|MYR|MZN|NAD|NGN|NIO|NOK|NPR|NZD|OMR|PAB|PEN|PGK|PHP|PKR|PLN|PYG|QAR|RON|RSD|RUB|RWF|SAR|SBD|SCR|SDG|SEK|SGD|SHP|SLL|SOS|SPL|SRD|STD|SVC|SYP|SZL|THB|TJS|TMT|TND|TOP|TRY|TTD|TVD|TWD|TZS|UAH|UGX|USD|UYU|UZS|VEF|VND|VUV|WST|XAF|XCD|XDR|XOF|XPF|YER|ZAR|ZMW|ZWD$/


for name, value of constants
  exports[name] = value

exports.BASE_HEADERS = [
  constants.HEADER_PRODUCT_TYPE,
  constants.HEADER_VARIANT_ID
]

exports.BASE_LOCALIZED_HEADERS = [
  constants.HEADER_NAME,
  constants.HEADER_DESCRIPTION
  constants.HEADER_SLUG,
  constants.HEADER_META_TITLE,
  constants.HEADER_META_DESCRIPTION,
  constants.HEADER_META_KEYWORDS,
  constants.HEADER_SEARCH_KEYWORDS
]

exports.SPECIAL_HEADERS = [
  constants.HEADER_ID,
  constants.HEADER_SKU,
  constants.HEADER_PRICES,
  constants.HEADER_TAX,
  constants.HEADER_CATEGORIES,
  constants.HEADER_IMAGES,
  # TODO: image labels and dimensions
]

exports.ALL_HEADERS = exports.BASE_HEADERS.concat(exports.BASE_LOCALIZED_HEADERS.concat(exports.SPECIAL_HEADERS))
