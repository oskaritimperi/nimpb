import json
import strutils
import times

include timestamp_pb

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
