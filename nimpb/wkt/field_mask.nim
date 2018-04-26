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
    # TODO
    result = s

proc toJson*(message: google_protobuf_FieldMask): JsonNode =
    var resultString = ""

    for index, path in message.paths:
        add(resultString, snakeCaseToCamelCase(path))
        if index < len(message.paths)-1:
            add(resultString, ",")

    result = %resultString
