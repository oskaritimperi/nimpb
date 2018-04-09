import base64
import math
import pegs
import std/json
import strutils
import times

import nimpb
import util

import wkt/duration_pb
import wkt/timestamp_pb
import wkt/wrappers_pb
import wkt/field_mask_pb
import wkt/struct_pb
import wkt/any_pb

type
    JsonParseError = object of nimpb.ParseError

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
        add(s, intToStr(sgn(message.nanos) * message.nanos, 9))
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
    var s = ""

    for path in message.paths:
        add(s, toCamelCase(path))
        add(s, ",")

    setLen(s, len(s) - 1)

    result = %s

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
        raise newException(JsonParseError, "not an integer")

proc parseInt*[T: uint32|uint64](node: JsonNode): T =
    if node.kind == JString:
        result = T(parseBiggestUInt(node.str))
    elif node.kind == JInt:
        result = T(getBiggestInt(node))
    else:
        raise newException(JsonParseError, "not an integer")

proc parseString*(node: JsonNode): string =
    if node.kind != JString:
        raise newException(JsonParseError, "not a string")
    result = node.str

proc parseBytes*(node: JsonNode): bytes =
    if node.kind != JString:
        raise newException(JsonParseError, "not a string")
    result = bytes(base64.decode(node.str))

proc parseBool*(node: JsonNode): bool =
    if node.kind != JBool:
        raise newException(JsonParseError, "not a boolean")
    result = getBool(node)

proc parsegoogle_protobuf_DoubleValueFromJson*(node: JsonNode): google_protobuf_DoubleValue =
    if node.kind != JFloat:
        raise newException(JsonParseError, "not a float")
    result = newgoogle_protobuf_DoubleValue()
    result.value = getFloat(node)

proc parsegoogle_protobuf_FloatValueFromJson*(node: JsonNode): google_protobuf_FloatValue =
    if node.kind != JFloat:
        raise newException(JsonParseError, "not a float")
    result = newgoogle_protobuf_FloatValue()
    result.value = getFloat(node)

proc parsegoogle_protobuf_Int64ValueFromJson*(node: JsonNode): google_protobuf_Int64Value =
    result = newgoogle_protobuf_Int64Value()
    if node.kind == JInt:
        result.value = getBiggestInt(node)
    elif node.kind == JString:
        result.value = parseBiggestInt(node.str)
    else:
        raise newException(JsonParseError, "invalid value")

proc parsegoogle_protobuf_UInt64ValueFromJson*(node: JsonNode): google_protobuf_UInt64Value =
    result = newgoogle_protobuf_UInt64Value()
    if node.kind == JInt:
        result.value = uint64(getBiggestInt(node))
    elif node.kind == JString:
        result.value = uint64(parseBiggestUInt(node.str))
    else:
        raise newException(JsonParseError, "invalid value")

proc parsegoogle_protobuf_Int32ValueFromJson*(node: JsonNode): google_protobuf_Int32Value =
    result = newgoogle_protobuf_Int32Value()
    if node.kind == JInt:
        result.value = int32(getInt(node))
    elif node.kind == JString:
        result.value = int32(parseInt(node.str))
    else:
        raise newException(JsonParseError, "invalid value")

proc parsegoogle_protobuf_UInt32ValueFromJson*(node: JsonNode): google_protobuf_UInt32Value =
    result = newgoogle_protobuf_UInt32Value()
    if node.kind == JInt:
        result.value = uint32(getInt(node))
    elif node.kind == JString:
        result.value = uint32(parseUInt(node.str))
    else:
        raise newException(JsonParseError, "invalid value")

proc parsegoogle_protobuf_BoolValueFromJson*(node: JsonNode): google_protobuf_BoolValue =
    if node.kind != JBool:
        raise newException(JsonParseError, "not a boolean")
    result = newgoogle_protobuf_BoolValue()
    result.value = getBool(node)

proc parsegoogle_protobuf_StringValueFromJson*(node: JsonNode): google_protobuf_StringValue =
    if node.kind != JString:
        raise newException(JsonParseError, "not a string")
    result = newgoogle_protobuf_StringValue()
    result.value = node.str

proc parsegoogle_protobuf_BytesValueFromJson*(node: JsonNode): google_protobuf_BytesValue =
    if node.kind != JString:
        raise newException(JsonParseError, "not a string")
    result = newgoogle_protobuf_BytesValue()
    result.value = bytes(base64.decode(node.str))

proc parsegoogle_protobuf_DurationFromJson*(node: JsonNode): google_protobuf_Duration =
    if node.kind != JString:
        raise newException(JsonParseError, "string expected")

    if not endsWith(node.str, "s"):
        raise newException(JsonParseError, "string does not end with s")

    result = newgoogle_protobuf_Duration()

    let dotIndex = find(node.str, '.')

    if dotIndex == -1:
        result.seconds = parseBiggestInt(node.str[0..^2])
        if result.seconds < -315_576_000_000'i64 or
           result.seconds > 315_576_000_000'i64:
           raise newException(JsonParseError, "duration seconds out of bounds")
        return

    result.seconds = parseBiggestInt(node.str[0..dotIndex-1])

    if result.seconds < -315_576_000_000'i64 or
       result.seconds > 315_576_000_000'i64:
       raise newException(JsonParseError, "duration seconds out of bounds")

    let nanoStr = node.str[dotIndex+1..^2]
    var factor = 100_000_000

    result.nanos = 0

    for ch in nanoStr:
        result.nanos = result.nanos + int32(factor * (ord(ch) - ord('0')))
        factor = factor div 10

    if result.nanos > 999_999_999:
        raise newException(ValueError, "duration nanos out of bounds")

    if result.seconds < 0:
        result.nanos = -result.nanos

proc parsegoogle_protobuf_TimestampFromJson*(node: JsonNode): google_protobuf_Timestamp =
    if node.kind != JString:
        raise newException(JsonParseError, "string expected")

    let pattern = peg"""
timestamp <- year '-' month '-' day 'T' hours ':' mins ':' secs {frac?} {offset}
year <- \d\d\d\d
month <- \d\d
day <- \d\d
hours <- \d\d
mins <- \d\d
secs <- \d\d
frac <- '.' \d+
offset <- 'Z' / (('+' / '-') \d\d ':' \d\d)
"""

    var matches: array[2, string]
    var s = node.str
    var nanos = 0

    if not match(s, pattern, matches):
        raise newException(JsonParseError, "invalid timestamp")

    if len(matches[0]) > 0:
        # Delete the fractions if they were found so that times.parse() can
        # parse the rest of the timestamp.
        let first = len(s) - len(matches[1]) - len(matches[0])
        let last = len(s) - len(matches[1]) - 1
        delete(s, first, last)

        var factor = 100_000_000
        for ch in matches[0][1..^1]:
            nanos = nanos + factor * (ord(ch) - ord('0'))
            factor = factor div 10

        if nanos > 999_999_999:
            raise newException(JsonParseError, "nanos out of bounds")

    var dt: DateTime

    try:
        dt = times.parse(s, "yyyy-MM-dd'T'HH:mm:sszzz", utc())
    except Exception as exc:
        raise newException(JsonParseError, exc.msg)

    if dt.year < 1 or dt.year > 9999:
        raise newException(JsonParseError, "year out of bounds")

    result = newgoogle_protobuf_Timestamp()

    result.seconds = toUnix(toTime(dt))
    result.nanos = int32(nanos)

proc parsegoogle_protobuf_FieldMaskFromJson*(node: JsonNode): google_protobuf_FieldMask =
    if node.kind != JString:
        raise newException(JsonParseError, "string expected")

    result = newgoogle_protobuf_FieldMask()
    result.paths = @[]

    for path in split(node.str, ","):
        addPaths(result, toSnakeCase(path))

proc parsegoogle_protobuf_ValueFromJson*(node: JsonNode): google_protobuf_Value

proc parsegoogle_protobuf_StructFromJson*(node: JsonNode): google_protobuf_Struct =
    if node.kind != JObject:
        raise newException(JsonParseError, "object expected")

    result = newgoogle_protobuf_Struct()

    for key, valueNode in node:
        let value = parsegoogle_protobuf_ValueFromJson(valueNode)
        result.fields[key] = value

proc parsegoogle_protobuf_ListValueFromJson*(node: JsonNode): google_protobuf_ListValue

proc parsegoogle_protobuf_ValueFromJson*(node: JsonNode): google_protobuf_Value =
    result = newgoogle_protobuf_Value()

    if node.kind == JNull:
        result.nullValue = google_protobuf_NullValue.NULL_VALUE
    elif node.kind == JInt or node.kind == JFloat:
        result.numberValue = getFloat(node)
    elif node.kind == JString:
        result.stringValue = getStr(node)
    elif node.kind == JBool:
        result.boolValue = getBool(node)
    elif node.kind == JObject:
        result.structValue = parsegoogle_protobuf_StructFromJson(node)
    elif node.kind == JArray:
        result.listValue = parsegoogle_protobuf_ListValueFromJson(node)

proc parsegoogle_protobuf_NullValueFromJson*(node: JsonNode): google_protobuf_NullValue =
    if node.kind != JNull:
        raise newException(JsonParseError, "null expected")
    result = google_protobuf_NullValue.NULL_VALUE

proc parsegoogle_protobuf_ListValueFromJson*(node: JsonNode): google_protobuf_ListValue =
    if node.kind != JArray:
        raise newException(JsonParseError, "array expected")

    result = newgoogle_protobuf_ListValue()

    for value in node:
        addValues(result, parsegoogle_protobuf_ValueFromJson(value))

proc parsegoogle_protobuf_AnyFromJson*(node: JsonNode): google_protobuf_Any =
    discard
