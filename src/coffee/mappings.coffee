_ = require 'underscore'
_.mixin require('underscore-mixins')
csv = require 'csv'
CONS = require './constants'

class CustomFieldMappings

  constructor: (options = {}) ->
    @errors = []

  mapFieldTypes: (fieldDefinitions, typeDefinitionKey, rowIndex, key, value) ->
    result = undefined
    _.each fieldDefinitions, (fieldDefinition) =>
      if fieldDefinition.name is key
        switch fieldDefinition.type.name
          when 'Number' then result = @mapNumber value,typeDefinitionKey,rowIndex
          when 'Boolean' then result = @mapBoolean value,typeDefinitionKey,rowIndex
          when 'Money' then result = @mapMoney value,typeDefinitionKey,rowIndex
          when 'LocalizedString' then result = @mapLocalizedString value, typeDefinitionKey, rowIndex
          when 'Set' then result = @mapSet value,typeDefinitionKey,rowIndex,fieldDefinition.type.elementType
          else result = value
      # throw new Error "Field definition for '#{key}' does not exist on type '#{typeDefinitionKey}'."
    result

  isValidValue: (rawValue) ->
    return _.isString(rawValue) and rawValue.length > 0

  mapNumber: (rawNumber, typeDefinitionKey, rowIndex, regEx = CONS.REGEX_INTEGER) ->
    return unless @isValidValue(rawNumber)
    matchedNumber = regEx.exec rawNumber
    unless matchedNumber
      @errors.push "[row #{rowIndex}:#{typeDefinitionKey}] The number '#{rawNumber}' isn't valid!"
      return
    parseInt matchedNumber[0],10

  # 123,77,my-type,12,"nac.de;eafe.en"
  mapLocalizedString: (value, typeDefinitionKey, rowIndex, regEx = CONS.REGEX_LANGUAGE) ->
    result = {}
    value = value.split(';')
    _.each value, (str) =>
      matchedLocalisedString = regEx.exec str
      if matchedLocalisedString
        str = str.split('.')
        result[str[1]] = str[0]
      else
        @errors.push "[row #{rowIndex}:#{typeDefinitionKey}] The value '#{value}' isn't valid!. Supported format is 'foo.de'"

    return if _.isEmpty result
    result

  mapSet: (values, typeDefinitionKey, rowIndex, elementType) ->
    result = undefined
    values = values.split(',')
    result = _.map values, (value) =>
      switch elementType.name
        when 'Number' then @mapNumber value,typeDefinitionKey,rowIndex
        when 'Boolean' then @mapBoolean value,typeDefinitionKey,rowIndex
        when 'Money' then @mapMoney value,typeDefinitionKey,rowIndex
        when 'LocalizedString' then @mapLocalizedString value, typeDefinitionKey, rowIndex
        else value
    _.reject(result, _.isUndefined)

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

    validCurr = CONS.REGEX_CUR.exec matchedMoney[1]
    unless validCurr
      @errors.push "[row #{rowIndex}:#{typeDefinitionKey}] Parsed currency is not valid '#{rawMoney}'!"
      return

    money =
      currencyCode: matchedMoney[1].toUpperCase()
      centAmount: parseInt matchedMoney[2],10

module.exports = CustomFieldMappings
