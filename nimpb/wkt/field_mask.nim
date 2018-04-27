import json
import strutils

include field_mask_pb

const
    LowerCaseLetters = {'a'..'z'}

proc snakeCaseToCamelCase(s: string): string =
    # Nimification from https://github.com/google/protobuf/blob/master/src/google/protobuf/util/field_mask_util.cc
    result = newStringOfCap(len(s))

    var afterUnderscore = false

    for ch in s:
        if isUpperAscii(ch):
            raise newException(ValueError, "string not in snake case")

        if afterUnderscore:
            if ch in LowerCaseLetters:
                add(result, toUpperAscii(ch))
                afterUnderscore = false
            else:
                raise newException(ValueError, "lower case expected after underscore")
        elif ch == '_':
            afterUnderscore = true
        else:
            add(result, ch)

    if afterUnderscore:
        raise newException(ValueError, "trailing underscore")

proc camelCaseToSnakeCase(s: string): string =
    # Nimification from https://github.com/google/protobuf/blob/master/src/google/protobuf/util/field_mask_util.cc
    result = newStringOfCap(len(s) * 2)
    for ch in s:
        if ch == '_':
            raise newException(ValueError, "unexpected underscore")
        if isUpperAscii(ch):
            add(result, '_')
            add(result, toLowerAscii(ch))
        else:
            add(result, ch)

proc toJson*(message: google_protobuf_FieldMask): JsonNode =
    var resultString = ""

    for index, path in message.paths:
        add(resultString, snakeCaseToCamelCase(path))
        if index < len(message.paths)-1:
            add(resultString, ",")

    result = %resultString

proc parsegoogle_protobuf_FieldMask*(node: JsonNode): google_protobuf_FieldMask =
    if node.kind != JString:
        raise newException(nimpb_json.ParseError, "string expected")

    result = newgoogle_protobuf_FieldMask()
    result.paths = @[]

    try:
        for path in split(node.str, ","):
            addPaths(result, camelCaseToSnakeCase(path))
    except ValueError as exc:
        raise newException(nimpb_json.ParseError, exc.msg)
