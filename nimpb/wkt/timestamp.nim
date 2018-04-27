import json
import pegs
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

proc parsegoogle_protobuf_Timestamp*(node: JsonNode): google_protobuf_Timestamp =
    if node.kind != JString:
        raise newException(nimpb_json.ParseError, "string expected")

    var pattern = peg"""
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
        raise newException(nimpb_json.ParseError, "invalid timestamp")

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
            raise newException(nimpb_json.ParseError, "nanos out of bounds")

    var dt: DateTime

    try:
        dt = times.parse(s, "yyyy-MM-dd'T'HH:mm:sszzz", utc())
    except Exception as exc:
        raise newException(nimpb_json.ParseError, exc.msg)

    if dt.year < 1 or dt.year > 9999:
        raise newException(nimpb_json.ParseError, "year out of bounds")

    result = newgoogle_protobuf_Timestamp()

    setSeconds(result, toUnix(toTime(dt)))
    setNanos(result, int32(nanos))
