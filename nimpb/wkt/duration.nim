import json
import math
import strutils

include duration_pb

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
