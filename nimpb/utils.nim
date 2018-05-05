## This module implements some misc utilities.

import strutils

proc toCamelCase*(s: string): string =
    ## Nimification of ToCamelCase() from
    ## protobuf/src/google/protobuf/util/internal/utility.cc
    result = newStringOfCap(len(s))

    var
        capitalizeNext = false
        wasCapital = false
        isCapital = false
        firstWord = true

    for index in 0..len(s)-1:
        let ch = s[index]
        wasCapital = isCapital
        isCapital = isUpperAscii(ch)
        if ch == '_':
            capitalizeNext = true
            if len(result) > 0:
                firstWord = false
        elif firstWord:
            if len(result) > 0 and isCapital and (not wasCapital or (index+1 < len(s) and isLowerAscii(s[index+1]))):
                firstWord = false
                add(result, ch)
            else:
                add(result, toLowerAscii(ch))
        elif capitalizeNext:
            capitalizeNext = false
            add(result, toUpperAscii(ch))
        else:
            add(result, toLowerAscii(ch))

proc toSnakeCase*(s: string): string =
    ## Nimification of ToSnakeCase() from
    ## protobuf/src/google/protobuf/util/internal/utility.cc
    result = newStringOfCap(len(s) * 2)

    var
        wasNotUnderscore = false
        wasNotCap = false

    for index in 0..len(s)-1:
        if isUpperAscii(s[index]):
            if wasNotUnderscore and
               (wasNotCap or
                (index+1 < len(s) and isLowerAscii(s[index+1]))):
                add(result, '_')
            add(result, toLowerAscii(s[index]))
            wasNotUnderscore = true
            wasNotCap = false
        else:
            add(result, s[index])
            wasNotUnderscore = s[index] != '_'
            wasNotCap = true
