## This module implements protobuf3 JSON serializing and deserializing for some
## primitive types.

import base64
import math
import std/json
import strutils
import times

import nimpb

type
    ParseError* = object of nimpb.ParseError

proc `%`*(u: uint32): JsonNode =
    newJFloat(float(u))

proc `%`*(b: seq[byte]): JsonNode =
    result = newJString(base64.encode(cast[string](b), newLine=""))

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

proc toJson*[Enum: enum](value: Enum): JsonNode =
    for v in Enum:
        if value == v:
            return %($v)
    # The enum has a value that is not defined in the enum type
    result = %(cast[int](value))

proc parseEnum*[T](node: JsonNode): T =
    if node.kind == JString:
        result = parseEnum[T](node.str)
    elif node.kind == JInt:
        result = cast[T](node.num)
    else:
        raise newException(ParseError, "invalid enum value")

proc parseFloat*[T: float32|float64](node: JsonNode): T =
    if node.kind == JString:
        if node.str == "NaN":
            return NaN
        elif node.str == "Infinity":
            return Inf
        elif node.str == "-Infinity":
            return NegInf
        else:
            result = T(parseFloat(node.str))
    else:
        result = T(getFloat(node))

    case classify(result)
    of fcInf: raise newException(ParseError, "invalid floating point number")
    of fcNegInf: raise newException(ParseError, "invalid floating point number")
    of fcNan: raise newException(ParseError, "invalid floating point number")
    else: discard

proc parseInt*[T: int32|int64](node: JsonNode): T =
    var big: BiggestInt

    if node.kind == JString:
        try:
            big = parseBiggestInt(node.str)
        except Exception as exc:
            raise newException(ParseError, exc.msg)
    elif node.kind == JInt:
        big = getBiggestInt(node)
    elif node.kind == JFloat:
        let f = getFloat(node)
        if trunc(f) != f:
            raise newException(ParseError, "not an integer")
        big = BiggestInt(f)
    else:
        raise newException(ParseError, "not an integer")

    if big < BiggestInt(low(T)) or big > BiggestInt(high(T)):
        raise newException(ParseError, "integer out of bounds")

    result = T(big)

proc high(t: typedesc[uint64]): uint64 = 18446744073709551615'u64

proc parseInt*[T: uint32|uint64](node: JsonNode): T =
    var big: BiggestUInt

    if node.kind == JString:
        try:
            big = parseBiggestUInt(node.str)
        except Exception as exc:
            raise newException(ParseError, exc.msg)
    elif node.kind == JInt:
        # raise newException(ParseError, "expected quoted")
        big = BiggestUInt(getBiggestInt(node))
    elif node.kind == JFloat:
        let f = getFloat(node)
        if trunc(f) != f:
            raise newException(ParseError, "not an integer")
        big = BiggestUInt(f)
    else:
        raise newException(ParseError, "not an integer")

    if big > BiggestUInt(high(T)):
        raise newException(ParseError, "integer out of bounds")

    result = T(big)

proc parseString*(node: JsonNode): string =
    if node.kind != JString:
        raise newException(ParseError, "not a string")
    result = node.str

proc parseBytes*(node: JsonNode): seq[byte] =
    if node.kind != JString:
        raise newException(ParseError, "not a string")
    result = cast[seq[byte]](base64.decode(node.str))

proc parseBool*(node: JsonNode): bool =
    if node.kind != JBool:
        raise newException(ParseError, "not a boolean")
    result = getBool(node)

proc getJsonField*(obj: JsonNode, name, jsonName: string): JsonNode =
    if jsonName in obj:
        result = obj[jsonName]
    elif name in obj:
        result = obj[name]
