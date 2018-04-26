import json
import strutils
import base64

include wrappers_pb

proc toJson*(message: google_protobuf_DoubleValue): JsonNode =
    if hasValue(message):
        result = toJson(message.value)
    else:
        result = newJNull()

proc toJson*(message: google_protobuf_FloatValue): JsonNode =
    if hasValue(message):
        result = toJson(message.value)
    else:
        result = newJNull()

proc toJson*(message: google_protobuf_Int64Value): JsonNode =
    if hasValue(message):
        result = toJson(message.value)
    else:
        result = newJNull()

proc toJson*(message: google_protobuf_UInt64Value): JsonNode =
    if hasValue(message):
        result = toJson(message.value)
    else:
        result = newJNull()

proc toJson*(message: google_protobuf_Int32Value): JsonNode =
    if hasValue(message):
        result = %message.value
    else:
        result = newJNull()

proc toJson*(message: google_protobuf_UInt32Value): JsonNode =
    if hasValue(message):
        result = %message.value
    else:
        result = newJNull()

proc toJson*(message: google_protobuf_BoolValue): JsonNode =
    if hasValue(message):
        result = %message.value
    else:
        result = newJNull()

proc toJson*(message: google_protobuf_StringValue): JsonNode =
    if hasValue(message):
        result = %message.value
    else:
        result = newJNull()

proc toJson*(message: google_protobuf_BytesValue): JsonNode =
    if hasValue(message):
        result = %message.value
    else:
        result = newJNull()

proc parsegoogle_protobuf_DoubleValue*(node: JsonNode): google_protobuf_DoubleValue =
    result = newgoogle_protobuf_DoubleValue()
    if node.kind == JInt or node.kind == JFloat:
        setValue(result, getFloat(node))
    else:
        raise newException(nimpb_json.ParseError, "not a float")

proc parsegoogle_protobuf_FloatValue*(node: JsonNode): google_protobuf_FloatValue =
    result = newgoogle_protobuf_FloatValue()
    if node.kind == JInt or node.kind == JFloat:
        setValue(result, getFloat(node))
    else:
        raise newException(nimpb_json.ParseError, "not a float")

proc parsegoogle_protobuf_Int64Value*(node: JsonNode): google_protobuf_Int64Value =
    result = newgoogle_protobuf_Int64Value()
    if node.kind == JInt:
        setValue(result, getBiggestInt(node))
    elif node.kind == JString:
        setValue(result, parseBiggestInt(node.str))
    else:
        raise newException(nimpb_json.ParseError, "invalid value")

proc parsegoogle_protobuf_UInt64Value*(node: JsonNode): google_protobuf_UInt64Value =
    result = newgoogle_protobuf_UInt64Value()
    if node.kind == JInt:
        setValue(result, uint64(getBiggestInt(node)))
    elif node.kind == JString:
        setValue(result, uint64(parseBiggestUInt(node.str)))
    else:
        raise newException(nimpb_json.ParseError, "invalid value")

proc parsegoogle_protobuf_Int32Value*(node: JsonNode): google_protobuf_Int32Value =
    result = newgoogle_protobuf_Int32Value()
    if node.kind == JInt:
        setValue(result, int32(getInt(node)))
    elif node.kind == JString:
        setValue(result, int32(parseInt(node.str)))
    else:
        raise newException(nimpb_json.ParseError, "invalid value")

proc parsegoogle_protobuf_UInt32Value*(node: JsonNode): google_protobuf_UInt32Value =
    result = newgoogle_protobuf_UInt32Value()
    if node.kind == JInt:
        setValue(result, uint32(getInt(node)))
    elif node.kind == JString:
        setValue(result, uint32(parseUInt(node.str)))
    else:
        raise newException(nimpb_json.ParseError, "invalid value")

proc parsegoogle_protobuf_BoolValue*(node: JsonNode): google_protobuf_BoolValue =
    if node.kind != JBool:
        raise newException(nimpb_json.ParseError, "not a boolean")
    result = newgoogle_protobuf_BoolValue()
    setValue(result, getBool(node))

proc parsegoogle_protobuf_StringValue*(node: JsonNode): google_protobuf_StringValue =
    if node.kind != JString:
        raise newException(nimpb_json.ParseError, "not a string")
    result = newgoogle_protobuf_StringValue()
    setValue(result, node.str)

proc parsegoogle_protobuf_BytesValue*(node: JsonNode): google_protobuf_BytesValue =
    if node.kind != JString:
        raise newException(nimpb_json.ParseError, "not a string")
    result = newgoogle_protobuf_BytesValue()
    setValue(result, cast[seq[byte]](base64.decode(node.str)))
