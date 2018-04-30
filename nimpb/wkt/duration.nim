import json
import math
import strutils

include duration_pb
import utils

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

proc parsegoogle_protobuf_Duration*(node: JsonNode): google_protobuf_Duration =
    if node.kind != JString:
        raise newException(nimpb_json.ParseError, "string expected")

    if not endsWith(node.str, "s"):
        raise newException(nimpb_json.ParseError, "string does not end with s")

    result = newgoogle_protobuf_Duration()

    let dotIndex = find(node.str, '.')

    if dotIndex == -1:
        setSeconds(result, parseBiggestInt(node.str[0..^2]))
        if result.seconds < -315_576_000_000'i64 or
           result.seconds > 315_576_000_000'i64:
           raise newException(nimpb_json.ParseError, "duration seconds out of bounds")
        return

    setSeconds(result, parseBiggestInt(node.str[0..dotIndex-1]))

    if result.seconds < -315_576_000_000'i64 or
       result.seconds > 315_576_000_000'i64:
       raise newException(nimpb_json.ParseError, "duration seconds out of bounds")

    let nanoStr = node.str[dotIndex+1..^2]
    var factor = 100_000_000

    setNanos(result, 0)

    for ch in nanoStr:
        setNanos(result, result.nanos + int32(factor * (ord(ch) - ord('0'))))
        factor = factor div 10

    if result.nanos > 999_999_999:
        raise newException(ValueError, "duration nanos out of bounds")

    if result.seconds < 0:
        setNanos(result, -result.nanos)

declareJsonProcs(google_protobuf_Duration)
