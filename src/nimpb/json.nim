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
