import json

include struct_pb

proc toJson*(message: google_protobuf_Value): JsonNode

proc toJson*(message: google_protobuf_ListValue): JsonNode

proc toJson*(message: google_protobuf_Struct): JsonNode =
    result = newJObject()
    for key, value in message.fields:
        result[key] = toJson(value)

proc toJson*(message: google_protobuf_Value): JsonNode =
    if hasNullValue(message):
        result = newJNull()
    elif hasNumberValue(message):
        result = toJson(message.numberValue)
    elif hasStringValue(message):
        result = %message.stringValue
    elif hasBoolValue(message):
        result = %message.boolValue
    elif hasStructValue(message):
        result = toJson(message.structValue)
    elif hasListValue(message):
        result = toJson(message.listValue)
    else:
        raise newException(ValueError, "no field set")

proc toJson*(message: google_protobuf_NullValue): JsonNode =
    newJNull()

proc toJson*(message: google_protobuf_ListValue): JsonNode =
    result = newJArray()
    for value in message.values:
        add(result, toJson(value))
