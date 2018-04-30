import json

include struct_pb
import utils

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

proc parsegoogle_protobuf_Value*(node: JsonNode): google_protobuf_Value

proc parsegoogle_protobuf_ListValue*(node: JsonNode): google_protobuf_ListValue

proc parsegoogle_protobuf_Struct*(node: JsonNode): google_protobuf_Struct =
    if node.kind != JObject:
        raise newException(nimpb_json.ParseError, "object expected")

    result = newgoogle_protobuf_Struct()

    for key, valueNode in node:
        let value = parsegoogle_protobuf_Value(valueNode)
        result.fields[key] = value

proc parsegoogle_protobuf_Value*(node: JsonNode): google_protobuf_Value =
    result = newgoogle_protobuf_Value()

    if node.kind == JNull:
        setNullValue(result, google_protobuf_NullValue.NULL_VALUE)
    elif node.kind == JInt or node.kind == JFloat:
        setNumberValue(result, getFloat(node))
    elif node.kind == JString:
        setStringValue(result, getStr(node))
    elif node.kind == JBool:
        setBoolValue(result, getBool(node))
    elif node.kind == JObject:
        setStructValue(result, parsegoogle_protobuf_Struct(node))
    elif node.kind == JArray:
        setListValue(result, parsegoogle_protobuf_ListValue(node))

proc parsegoogle_protobuf_NullValue*(node: JsonNode): google_protobuf_NullValue =
    if node.kind != JNull:
        raise newException(nimpb_json.ParseError, "null expected")
    result = google_protobuf_NullValue.NULL_VALUE

proc parsegoogle_protobuf_ListValue*(node: JsonNode): google_protobuf_ListValue =
    if node.kind != JArray:
        raise newException(nimpb_json.ParseError, "array expected")

    result = newgoogle_protobuf_ListValue()

    for value in node:
        addValues(result, parsegoogle_protobuf_Value(value))

declareJsonProcs(google_protobuf_Value)
declareJsonProcs(google_protobuf_ListValue)
declareJsonProcs(google_protobuf_Struct)
# helper(google_protobuf_NullValue)
