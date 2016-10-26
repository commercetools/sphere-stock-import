
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
      ]

  it 'should initialize', ->
    expect(@map).toBeDefined()
    expect(@map.mapNumber).toBeDefined()
    expect(@map.mapLocalizedString).toBeDefined()
    expect(@map.mapSet).toBeDefined()
    expect(@map.mapMoney).toBeDefined()
    expect(@map.mapBoolean).toBeDefined()
    expect(@map.mapFieldTypes).toBeDefined()

  describe '::mapNumber', =>
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

  describe '::mapLocalizedString', =>
    it 'should convert to localizedString', ->
      result = @map.mapLocalizedString 'foo',@customTypeDefinition.key,2,'de'

      expect(result).toEqual {de: 'foo'}

    it 'should add error if value is not valid', ->
      result = @map.mapLocalizedString 'blue',@customTypeDefinition.key,2,'invalid'
      expect(result).not.toBeDefined()
      expect(@map.errors[0]).toBe "[row 2:my-category] localisedString  header 'invalid' format is not valid!"

  describe '::mapBoolean', =>
    it 'should convert to boolean', ->
      result = @map.mapBoolean 'true',@customTypeDefinition.key,2
      expect(result).toBe true

    it 'should add error if value is not a valid boolean', ->
      result = @map.mapBoolean 'invalid',@customTypeDefinition.key,2
      expect(result).not.toBeDefined()
      expect(@map.errors[0]).toBe "[row 2:my-category] The value \'invalid\' isn\'t a valid boolean!"

  describe '::mapFieldTypes', =>
    it 'should map String type', ->
      result = @map.mapFieldTypes @customTypeDefinition.fieldDefinitions,@customTypeDefinition.key,2,'stringtype','okay'
      expect(result).toBe 'okay'

    it 'should map Number type', ->
      result = @map.mapFieldTypes @customTypeDefinition.fieldDefinitions,@customTypeDefinition.key,2,'numbertype','123'
      expect(@map.errors).toEqual []
      expect(result).toBe 123

    it 'should map Boolean type', ->
      result = @map.mapFieldTypes @customTypeDefinition.fieldDefinitions,@customTypeDefinition.key,2,'booleantype','true'
      expect(result).toBe true
      expect(@map.errors).toEqual []
      result = @map.mapFieldTypes @customTypeDefinition.fieldDefinitions,@customTypeDefinition.key,2,'booleantype','false'
      expect(result).toBe false
      expect(@map.errors).toEqual []

    it 'should map Enum type', ->
      result = @map.mapFieldTypes @customTypeDefinition.fieldDefinitions,@customTypeDefinition.key,2,'enumtype','la'
      expect(result).toBe 'la'
      expect(@map.errors).toEqual []

    it 'should map localizedenumtype type', ->
      result = @map.mapFieldTypes @customTypeDefinition.fieldDefinitions,@customTypeDefinition.key,2,'localizedstringtype','la','de'
      expect(result).toEqual de: 'la'
      expect(@map.errors).toEqual []

    it 'should map money type', ->
      result = @map.mapFieldTypes @customTypeDefinition.fieldDefinitions,@customTypeDefinition.key,2,'money','EUR 1400'
      expect(result).toEqual currencyCode: 'EUR', centAmount: 1400
      expect(@map.errors).toEqual []

  describe '::mapSet', =>
    it 'should convert to set', ->
      elementType = name: 'Number'
      result = @map.mapSet '1,2,3,4',@customTypeDefinition.key,2,elementType
      expect(result).toEqual [1,2,3,4]

    it 'should add error if value valid and remove invalid values', ->
      elementType = name: 'Number'
      result = @map.mapSet '1,2,"3",4',@customTypeDefinition.key,2,elementType
      expect(result).toEqual [1,2,4]
      expect(@map.errors[0]).toBe "[row 2:my-category] The number '\"3\"' isn't valid!"

  describe '::mapMoney', =>
    it 'should convert to Money object', ->
      result = @map.mapMoney 'EUR 140',@customTypeDefinition.key,2
      expect(result).toEqual {currencyCode: 'EUR', centAmount: 140}

    it 'should add error if value is not a valid money format', ->
      result = @map.mapMoney 'invalid',@customTypeDefinition.key,2
      expect(result).not.toBeDefined()
      expect(@map.errors[0]).toBe "[row 2:my-category] Can not parse money 'invalid'!"
    it 'should add error if currency in money is not a valid currency', ->
      result = @map.mapMoney 'ABI 140',@customTypeDefinition.key,2
      expect(result).not.toBeDefined()
      expect(@map.errors[0]).toBe "[row 2:my-category] Parsed currency is not valid 'ABI 140'!"
