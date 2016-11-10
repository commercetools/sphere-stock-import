_ = require 'underscore'
_.mixin require('underscore-mixins')
csv = require 'csv'
CONS = require './constants'

class CustomFieldMappings

  constructor: (options = {}) ->
    @errors = []

  mapFieldTypes: ({fieldDefinitions, typeDefinitionKey, rowIndex, key, value, langHeader}) ->
    result = undefined
    _.each fieldDefinitions, (fieldDefinition) =>
      if fieldDefinition.name is key
        # Try to map the value type by getting the appropriate function
        try
          if fieldDefinition.type.name == 'LocalizedString'
            result = @['map' + fieldDefinition.type.name] value, typeDefinitionKey, rowIndex, langHeader
          else
            result = @['map' + fieldDefinition.type.name] value, typeDefinitionKey, rowIndex
        catch
          @errors.push "[row #{rowIndex}:#{typeDefinitionKey}] The type '#{fieldDefinition.type.name}' is not valid."
          return
    result

  mapSet: (values, typeDefinitionKey, rowIndex, elementType) ->
    result = undefined
    values = values.split(',')

    result = _.map values, (value) =>
      # Try to map the value type by getting the appropiate function
      try
        @['map' + elementType.name] value, typeDefinitionKey, rowIndex
      catch
        @errors.push "[row #{rowIndex}:#{typeDefinitionKey}] The type '#{elementType.name}' is not valid."
        return

    _.reject(result, _.isUndefined)

  isValidValue: (rawValue) ->
    return _.isString(rawValue) and rawValue.length > 0

  mapNumber: (rawNumber, typeDefinitionKey, rowIndex, regEx = CONS.REGEX_INTEGER) ->
    return unless @isValidValue(rawNumber)
    matchedNumber = regEx.exec rawNumber
    unless matchedNumber
      @errors.push "[row #{rowIndex}:#{typeDefinitionKey}] The number '#{rawNumber}' isn't valid!"
      return
    parseInt matchedNumber[0],10
  ###
  custom,customField.name.de,customField.name.en
  my-type,Hajo,Abi
  //- {
    custom: {
      name: {
        de: 'Hajo',
        en: 'Abi'
      }
    }
  }
  ###

  mapLocalizedString: (value, typeDefinitionKey, rowIndex, langHeader, regEx = CONS.REGEX_LANGUAGE) ->
    if !regEx.test langHeader
      @errors.push "[row #{rowIndex}:#{typeDefinitionKey}] localizedString  header '#{langHeader}' format is not valid!" unless regEx.test langHeader
      return
    else
      "#{langHeader}": value

  mapString: (rawString) -> rawString
  mapEnum: (rawEnum) -> rawEnum
  mapDate: (rawDate) -> rawDate
  mapTime: (rawTime) -> rawTime
  mapDateTime: (rawDateTime) -> rawDateTime

  mapBoolean: (rawBoolean, typeDefinitionKey, rowIndex) ->
    result = undefined
    if _.isUndefined(rawBoolean) or (_.isString(rawBoolean) and _.isEmpty(rawBoolean))
      return
    errorMsg = "[row #{rowIndex}:#{typeDefinitionKey}] The value '#{rawBoolean}' isn't a valid boolean!"
    try
      b = JSON.parse(rawBoolean.toLowerCase())
      if not _.isBoolean b
        @errors.push error
        return
      b
    catch
      @errors.push errorMsg
      return

  # EUR 300
  # USD 999
  mapMoney: (rawMoney, typeDefinitionKey, rowIndex) ->
    return unless @isValidValue(rawMoney)
    matchedMoney = CONS.REGEX_MONEY.exec rawMoney
    unless matchedMoney
      @errors.push "[row #{rowIndex}:#{typeDefinitionKey}] Can not parse money '#{rawMoney}'!"
      return

    money =
      currencyCode: matchedMoney[1].toUpperCase()
      centAmount: parseInt matchedMoney[2],10

module.exports = CustomFieldMappings
