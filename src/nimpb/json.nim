import base64
import math
import std/json
import strutils
import times

import nimpb

import wkt/duration_pb
import wkt/timestamp_pb
import wkt/wrappers_pb
import wkt/field_mask_pb
import wkt/struct_pb
import wkt/any_pb

proc `%`*(u: uint32): JsonNode =
    newJFloat(float(u))

proc `%`*(b: bytes): JsonNode =
    result = newJString(base64.encode(string(b), newLine=""))

proc toJson*(value: float): JsonNode =
    case classify(value)
    of fcNan: result = %"NaN"
    of fcInf: result = %"Infinity"
    of fcNegInf: result = %"-Infinity"
    else: result = %value

proc toJson*(value: float32): JsonNode =
    case classify(value)
    of fcNan: result = %"NaN"
    of fcInf: result = %"Infinity"
    of fcNegInf: result = %"-Infinity"
    else: result = %value

proc toJson*(value: int64): JsonNode =
    newJString($value)

proc toJson*(value: uint64): JsonNode =
    newJString($value)

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

proc toJson*(message: google_protobuf_Duration): JsonNode =
    if (message.seconds < -315_576_000_000'i64) or
       (message.seconds > 315_576_000_000'i64):
        raise newException(ValueError, "seconds out of bounds")

    if (message.nanos < -999_999_999'i32) or
       (message.nanos > 999_999_999'i32):
        raise newException(ValueError, "nanos out of bounds")

    if message.seconds != 0:
        if sgn(message.seconds) != sgn(message.nanos):
            raise newException(ValueError, "different sign for seconds and nanos")

    var s = $message.seconds

    if message.nanos != 0:
        add(s, ".")
        add(s, intToStr(message.nanos, 9))
        removeSuffix(s, '0')

    add(s, "s")

    result = %s

proc toJson*(message: google_protobuf_Timestamp): JsonNode =
    let t = utc(fromUnix(message.seconds))

    if t.year < 1 or t.year > 9999:
        raise newException(ValueError, "invalid timestamp")

    var s = format(t, "yyyy-MM-dd'T'HH:mm:ss")
    if message.nanos != 0:
        add(s, ".")
        add(s, intToStr(message.nanos, 9))
        removeSuffix(s, '0')
    add(s, "Z")
    result = %s

proc toJson*(message: google_protobuf_FieldMask): JsonNode =
    %join(message.paths, ",")

proc toJson*(message: google_protobuf_Value): JsonNode

proc toJson*(message: google_protobuf_Struct): JsonNode =
    result = newJObject()
    for key, value in message.fields:
        result[key] = toJson(value)

proc toJson*(message: google_protobuf_ListValue): JsonNode

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

proc toJson*(message: google_protobuf_Any): JsonNode =
    case message.typeUrl
    of "type.googleapis.com/google.protobuf.Duration":
        let duration = newGoogleProtobufDuration(string(message.value))
        result = newJObject()
        result["@type"] = %message.typeUrl
        result["value"] = toJson(duration)
    of "type.googleapis.com/google.protobuf.Empty":
        result = newJObject()
        result["@type"] = %message.typeUrl
        result["value"] = newJObject()
    of "type.googleapis.com/google.protobuf.FieldMask":
        let mask = newGoogleProtobufFieldMask(string(message.value))
        result = newJObject()
        result["@type"] = %message.typeUrl
        result["value"] = toJson(mask)
    of "type.googleapis.com/google.protobuf.Struct":
        let struct = newGoogleProtobufStruct(string(message.value))
        result = newJObject()
        result["@type"] = %message.typeUrl
        result["value"] = toJson(struct)
    of "type.googleapis.com/google.protobuf.Value":
        let value = newGoogleProtobufValue(string(message.value))
        result = newJObject()
        result["@type"] = %message.typeUrl
        result["value"] = toJson(value)
    of "type.googleapis.com/google.protobuf.ListValue":
        let lst = newGoogleProtobufListValue(string(message.value))
        result = newJObject()
        result["@type"] = %message.typeUrl
        result["value"] = toJson(lst)
    of "type.googleapis.com/google.protobuf.Timestamp":
        let value = newGoogleProtobufTimestamp(string(message.value))
        result = newJObject()
        result["@type"] = %message.typeUrl
        result["value"] = toJson(value)
    else:
        result = newJObject()
        result["typeUrl"] = %message.typeUrl
        result["value"] = %message.value

proc getJsonField*(obj: JsonNode, name, jsonName: string): JsonNode =
    if jsonName in obj:
        result = obj[jsonName]
    elif name in obj:
        result = obj[name]

proc parseEnum*[T](node: JsonNode): T =
    if node.kind == JString:
        result = parseEnum[T](node.str)
    elif node.kind == JInt:
        result = T(node.num)
    else:
        raise newException(ValueError, "invalid enum value")

proc parseFloat*(node: JsonNode): float =
    if node.kind == JString:
        if node.str == "NaN":
            result = NaN
        elif node.str == "Infinity":
            result = Inf
        elif node.str == "-Infinity":
            result = NegInf
        else:
            result = parseFloat(node.str)
    else:
        result = getFloat(node)

proc parseInt*[T: int32|int64](node: JsonNode): T =
    if node.kind == JString:
        result = T(parseBiggestInt(node.str))
    elif node.kind == JInt:
        result = T(getBiggestInt(node))
    else:
        raise newException(ValueError, "not an integer")

proc parseInt*[T: uint32|uint64](node: JsonNode): T =
    if node.kind == JString:
        result = T(parseBiggestUInt(node.str))
    elif node.kind == JInt:
        result = T(getBiggestInt(node))
    else:
        raise newException(ValueError, "not an integer")

proc parseString*(node: JsonNode): string =
    if node.kind != JString:
        raise newException(ValueError, "not a string")
    result = node.str

proc parseBytes*(node: JsonNode): bytes =
    if node.kind != JString:
        raise newException(ValueError, "not a string")
    result = bytes(base64.decode(node.str))

proc parseBool*(node: JsonNode): bool =
    if node.kind != JBool:
        raise newException(ValueError, "not a boolean")
    result = getBool(node)

proc parsegoogle_protobuf_DoubleValueFromJson*(node: JsonNode): google_protobuf_DoubleValue =
    if node.kind != JFloat:
        raise newException(ValueError, "not a float")
    result = newgoogle_protobuf_DoubleValue()
    result.value = getFloat(node)

proc parsegoogle_protobuf_FloatValueFromJson*(node: JsonNode): google_protobuf_FloatValue =
    if node.kind != JFloat:
        raise newException(ValueError, "not a float")
    result = newgoogle_protobuf_FloatValue()
    result.value = getFloat(node)

proc parsegoogle_protobuf_Int64ValueFromJson*(node: JsonNode): google_protobuf_Int64Value =
    result = newgoogle_protobuf_Int64Value()
    if node.kind == JInt:
        result.value = getBiggestInt(node)
    elif node.kind == JString:
        result.value = parseBiggestInt(node.str)
    else:
        raise newException(ValueError, "invalid value")

proc parsegoogle_protobuf_UInt64ValueFromJson*(node: JsonNode): google_protobuf_UInt64Value =
    result = newgoogle_protobuf_UInt64Value()
    if node.kind == JInt:
        result.value = uint64(getBiggestInt(node))
    elif node.kind == JString:
        result.value = uint64(parseBiggestUInt(node.str))
    else:
        raise newException(ValueError, "invalid value")

proc parsegoogle_protobuf_Int32ValueFromJson*(node: JsonNode): google_protobuf_Int32Value =
    result = newgoogle_protobuf_Int32Value()
    if node.kind == JInt:
        result.value = int32(getInt(node))
    elif node.kind == JString:
        result.value = int32(parseInt(node.str))
    else:
        raise newException(ValueError, "invalid value")

proc parsegoogle_protobuf_UInt32ValueFromJson*(node: JsonNode): google_protobuf_UInt32Value =
    result = newgoogle_protobuf_UInt32Value()
    if node.kind == JInt:
        result.value = uint32(getInt(node))
    elif node.kind == JString:
        result.value = uint32(parseUInt(node.str))
    else:
        raise newException(ValueError, "invalid value")

proc parsegoogle_protobuf_BoolValueFromJson*(node: JsonNode): google_protobuf_BoolValue =
    if node.kind != JBool:
        raise newException(ValueError, "not a boolean")
    result = newgoogle_protobuf_BoolValue()
    result.value = getBool(node)

proc parsegoogle_protobuf_StringValueFromJson*(node: JsonNode): google_protobuf_StringValue =
    if node.kind != JString:
        raise newException(ValueError, "not a string")
    result = newgoogle_protobuf_StringValue()
    result.value = node.str

proc parsegoogle_protobuf_BytesValueFromJson*(node: JsonNode): google_protobuf_BytesValue =
    if node.kind != JString:
        raise newException(ValueError, "not a string")
    result = newgoogle_protobuf_BytesValue()
    result.value = bytes(base64.decode(node.str))

proc parsegoogle_protobuf_DurationFromJson*(node: JsonNode): google_protobuf_Duration =
    discard

proc parsegoogle_protobuf_TimestampFromJson*(node: JsonNode): google_protobuf_Timestamp =
    discard

proc parsegoogle_protobuf_FieldMaskFromJson*(node: JsonNode): google_protobuf_FieldMask =
    discard

proc parsegoogle_protobuf_ValueFromJson*(node: JsonNode): google_protobuf_Value

proc parsegoogle_protobuf_StructFromJson*(node: JsonNode): google_protobuf_Struct =
    discard

proc parsegoogle_protobuf_ListValueFromJson*(node: JsonNode): google_protobuf_ListValue

proc parsegoogle_protobuf_ValueFromJson*(node: JsonNode): google_protobuf_Value =
    discard

proc parsegoogle_protobuf_NullValueFromJson*(node: JsonNode): google_protobuf_NullValue =
    discard

proc parsegoogle_protobuf_ListValueFromJson*(node: JsonNode): google_protobuf_ListValue =
    discard

proc parsegoogle_protobuf_AnyFromJson*(node: JsonNode): google_protobuf_Any =
    discard
