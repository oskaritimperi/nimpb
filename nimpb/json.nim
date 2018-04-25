import base64
import math
import std/json
import strutils
import times

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
