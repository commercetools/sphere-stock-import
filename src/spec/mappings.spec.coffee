
Mappings = require '../lib/mappings'

describe 'Mappings', ->
  beforeEach ->
    @map = new Mappings()
    @customTypeDefinition =
      key: 'my-category'
      "fieldDefinitions": [
        {
          "name": "stringtype",
          "type": {
            "name": "String"
          },
        },
        {
          "name": "booleantype",
          "type": {
            "name": "Boolean"
          },
        },
        {
          "name": "money",
          "type": {
            "name": "Money"
          },
        },
        {
          "name": "numbertype",
          "type": {
            "name": "Number"
          },
        },
        {
          "name": "localizedstringtype",
          "type": {
            "name": "LocalizedString"
          },
        },
        {
          "name": "enumtype",
          "type": {
            "name": "Enum",
            "values": [
              {
                "key": "en",
                "label": "okay"
              }
            ]
          },
        },
        {
          "name": "localizedenumtype",
          "type": {
            "name": "LocalizedEnum",
            "values": [
              {
                "key": "enwew",
                "label": {
                  "de": "Hundefutter",
                  "en": "dog food"
                }
              }
            ]
          },
        },
        {
          "name": "settype",
          "type": {
            "name": "Set",
            "elementType": {
              "name": "Number"
            }
          },
        },
        {
          "name": "datetype",
          "type": {
            "name": "Date"
          },
        },
        {
          "name": "datetimetype",
          "type": {
            "name": "DateTime"
          },
        },
        {
          "name": "time",
          "type": {
            "name": "Time"
          },
        }
        {
          "name": "emoji",
          "type": {
            "name": "Emoji"
          },
        },
      ]

  it 'should initialize', ->
    expect(@map).toBeDefined()
    expect(@map.mapNumber).toBeDefined()
    expect(@map.mapLocalizedString).toBeDefined()
    expect(@map.mapSet).toBeDefined()
    expect(@map.mapMoney).toBeDefined()
    expect(@map.mapBoolean).toBeDefined()
    expect(@map.mapFieldTypes).toBeDefined()

  describe '::mapNumber', ->
    it 'should convert strings to integer', ->
      result = @map.mapNumber '3',@customTypeDefinition.key,2

      expect(typeof result).toBe 'number'
    it 'should return undefined is input is not a string', ->
      result = @map.mapNumber 3,@customTypeDefinition.key,2

      expect(@map.errors.length).toBe 0
      expect(result).not.toBeDefined()

    it 'should return error if input does not contain only numbers', ->
      result = @map.mapNumber '123error',@customTypeDefinition.key,2
      expect(@map.errors.length).toBe 1
      expect(@map.errors[0]).toBe "[row 2:my-category] The number '123error' isn't valid!"
      expect(result).not.toBeDefined()

  describe '::mapLocalizedString', ->
    it 'should convert to localizedString', ->
      result = @map.mapLocalizedString 'foo',@customTypeDefinition.key,2,'de'

      expect(result).toEqual {de: 'foo'}

    it 'should add error if value is not valid', ->
      result = @map.mapLocalizedString 'blue',@customTypeDefinition.key,2,'invalid'
      expect(result).not.toBeDefined()
      expect(@map.errors[0]).toBe "[row 2:my-category] localizedString  header 'invalid' format is not valid!"

  describe '::mapBoolean', ->
    it 'should convert to boolean', ->
      result = @map.mapBoolean 'true',@customTypeDefinition.key,2
      expect(result).toBe true

    it 'should add error if value is not a valid boolean', ->
      result = @map.mapBoolean 'invalid',@customTypeDefinition.key,2
      expect(result).not.toBeDefined()
      expect(@map.errors[0]).toBe "[row 2:my-category] The value \'invalid\' isn\'t a valid boolean!"

  describe '::mapFieldTypes', ->
    it 'should map String type', ->
      result = @map.mapFieldTypes({
        fieldDefinitions: @customTypeDefinition.fieldDefinitions,
        typeDefinitionKey: @customTypeDefinition.key,
        rowIndex: 2,
        key: 'stringtype',
        value: 'okay',
      })
      expect(result).toBe 'okay'

    it 'should map Number type', ->
      result = @map.mapFieldTypes({
        fieldDefinitions: @customTypeDefinition.fieldDefinitions,
        typeDefinitionKey: @customTypeDefinition.key,
        rowIndex: 2,
        key: 'numbertype',
        value: '123',
      })
      expect(@map.errors).toEqual []
      expect(result).toBe 123

    it 'should map Boolean type', ->
      result = @map.mapFieldTypes({
        fieldDefinitions: @customTypeDefinition.fieldDefinitions,
        typeDefinitionKey: @customTypeDefinition.key,
        rowIndex: 2,
        key: 'booleantype',
        value: 'true',
      })
      expect(result).toBe true
      expect(@map.errors).toEqual []
      
    it 'should map LocalizedString type', ->
      result = @map.mapFieldTypes({
        fieldDefinitions: @customTypeDefinition.fieldDefinitions,
        typeDefinitionKey: @customTypeDefinition.key,
        rowIndex: 2,
        key: 'localizedstringtype',
        value: 'hallo',
        langHeader: 'nl',
      })
      expect(result).toEqual {nl: 'hallo'}
      expect(@map.errors).toEqual []

    it 'should map Enum type', ->
      result = @map.mapFieldTypes({
        fieldDefinitions: @customTypeDefinition.fieldDefinitions,
        typeDefinitionKey: @customTypeDefinition.key,
        rowIndex: 2,
        key: 'enumtype',
        value: 'la',
      })
      expect(result).toBe 'la'
      expect(@map.errors).toEqual []

    it 'should map LocalizedEnum type', ->
      result = @map.mapFieldTypes({
        fieldDefinitions: @customTypeDefinition.fieldDefinitions,
        typeDefinitionKey: @customTypeDefinition.key,
        rowIndex: 2,
        key: 'localizedenumtype',
        value: 'la',
        langHeader: 'de',
      })
      expect(result).toEqual 'la'
      expect(@map.errors).toEqual []

    it 'should map money type', ->
      result = @map.mapFieldTypes({
        fieldDefinitions: @customTypeDefinition.fieldDefinitions,
        typeDefinitionKey: @customTypeDefinition.key,
        rowIndex: 2,
        key: 'money',
        value: 'EUR 1400',
      })
      expect(result).toEqual currencyCode: 'EUR', centAmount: 1400
      expect(@map.errors).toEqual []
      
    it 'should add error if type is not supported', ->
      result = @map.mapFieldTypes({
        fieldDefinitions: @customTypeDefinition.fieldDefinitions,
        typeDefinitionKey: @customTypeDefinition.key,
        rowIndex: 2,
        key: 'emoji',
        value: 'noop',
      })
      expect(result).toBe undefined
      expect(@map.errors).toEqual ['[row 2:my-category] The type \'Emoji\' is not supported.']

  describe '::mapSet', ->
    it 'should convert string set', ->
      elementType = name: 'String'
      result = @map.mapSet 'some,things', @customTypeDefinition.key, 2, elementType
      expect(result).toEqual ['some', 'things']

    it 'should convert boolean set', ->
      elementType = name: 'Boolean'
      result = @map.mapSet 'true,false,true', @customTypeDefinition.key, 2, elementType
      expect(result).toEqual [true, false, true]

    it 'should convert to number set', ->
      elementType = name: 'Number'
      result = @map.mapSet '1,2,3,4', @customTypeDefinition.key, 2, elementType
      expect(result).toEqual [1, 2, 3, 4]

    it 'should convert to money set', ->
      elementType = name: 'Money'
      result = @map.mapSet 'EUR 1400,JPY 9001', @customTypeDefinition.key, 2, elementType
      expect(result).toEqual [
        {'currencyCode': 'EUR', 'centAmount': 1400},
        {'currencyCode': 'JPY', 'centAmount': 9001}
      ]

    it 'should convert to enum set', ->
      elementType = name: 'Enum'
      result = @map.mapSet 'in,live', @customTypeDefinition.key, 2, elementType
      expect(result).toEqual ['in', 'live']

    it 'should convert to date set', ->
      elementType = name: 'Date'
      result = @map.mapSet '2016-09-11,2016-09-12', @customTypeDefinition.key, 2, elementType
      expect(result).toEqual ['2016-09-11', '2016-09-12']

    it 'should convert to time set', ->
      elementType = name: 'Time'
      result = @map.mapSet '14:00:00.000,15:00:00.000', @customTypeDefinition.key, 2, elementType
      expect(result).toEqual ['14:00:00.000', '15:00:00.000']

    it 'should convert to datetime set', ->
      elementType = name: 'DateTime'
      result = @map.mapSet '2001-09-11T14:00:00.000Z,2089-09-11T14:00:00.000Z', @customTypeDefinition.key, 2, elementType
      expect(result).toEqual ['2001-09-11T14:00:00.000Z', '2089-09-11T14:00:00.000Z']

    it 'should add error if type is not supported', ->
      elementType = name: 'Emoji'
      result = @map.mapSet '/O.O/,^_^', @customTypeDefinition.key, 2, elementType
      expect(result).toEqual []
      expect(@map.errors[0]).toBe '[row 2:my-category] The type \'Emoji\' is not supported.'

    it 'should add error if value valid and remove invalid values', ->
      elementType = name: 'Number'
      result = @map.mapSet '1,2,"3",4', @customTypeDefinition.key, 2, elementType
      expect(result).toEqual [1, 2, 4]
      expect(@map.errors[0]).toBe "[row 2:my-category] The number '\"3\"' isn't valid!"

  describe '::mapMoney', ->
    it 'should convert to Money object', ->
      result = @map.mapMoney 'EUR 140',@customTypeDefinition.key,2
      expect(result).toEqual {currencyCode: 'EUR', centAmount: 140}

    it 'should add error if value is not a valid money format', ->
      result = @map.mapMoney 'invalid',@customTypeDefinition.key,2
      expect(result).not.toBeDefined()
      expect(@map.errors[0]).toBe "[row 2:my-category] Can not parse money 'invalid'!"
