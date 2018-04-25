# Generated by protoc_gen_nim. Do not edit!

import base64
import intsets
import json

import nimpb/nimpb
import nimpb/json as nimpb_json

type
    Test1_MyEnum* {.pure.} = enum
        Foo = 0
        Bar = 1
    Test1* = ref Test1Obj
    Test1Obj* = object of Message
        a: int32
        e: Test1_MyEnum

proc newTest1*(): Test1
proc newTest1*(data: string): Test1
proc newTest1*(data: seq[byte]): Test1
proc writeTest1*(stream: Stream, message: Test1)
proc readTest1*(stream: Stream): Test1
proc sizeOfTest1*(message: Test1): uint64
proc toJson*(message: Test1): JsonNode

proc newTest1*(): Test1 =
    new(result)
    initMessage(result[])
    result.a = 0
    result.e = Test1_MyEnum.Foo

proc cleara*(message: Test1) =
    message.a = 0
    clearFields(message, [1])

proc hasa*(message: Test1): bool =
    result = hasField(message, 1)

proc seta*(message: Test1, value: int32) =
    message.a = value
    setField(message, 1)

proc a*(message: Test1): int32 {.inline.} =
    message.a

proc `a=`*(message: Test1, value: int32) {.inline.} =
    seta(message, value)

proc cleare*(message: Test1) =
    message.e = Test1_MyEnum.Foo
    clearFields(message, [2])

proc hase*(message: Test1): bool =
    result = hasField(message, 2)

proc sete*(message: Test1, value: Test1_MyEnum) =
    message.e = value
    setField(message, 2)

proc e*(message: Test1): Test1_MyEnum {.inline.} =
    message.e

proc `e=`*(message: Test1, value: Test1_MyEnum) {.inline.} =
    sete(message, value)

proc sizeOfTest1*(message: Test1): uint64 =
    if hasa(message):
        result = result + sizeOfTag(1, WireType.Varint)
        result = result + sizeOfInt32(message.a)
    if hase(message):
        result = result + sizeOfTag(2, WireType.Varint)
        result = result + sizeOfEnum[Test1_MyEnum](message.e)
    result = result + sizeOfUnknownFields(message)

proc writeTest1*(stream: Stream, message: Test1) =
    if hasa(message):
        protoWriteInt32(stream, message.a, 1)
    if hase(message):
        protoWriteEnum(stream, message.e, 2)
    writeUnknownFields(stream, message)

proc readTest1*(stream: Stream): Test1 =
    result = newTest1()
    while not atEnd(stream):
        let
            tag = readTag(stream)
            wireType = wireType(tag)
        case fieldNumber(tag)
        of 0:
            raise newException(InvalidFieldNumberError, "Invalid field number: 0")
        of 1:
            expectWireType(wireType, WireType.Varint)
            seta(result, protoReadInt32(stream))
        of 2:
            expectWireType(wireType, WireType.Varint)
            sete(result, protoReadEnum[Test1_MyEnum](stream))
        else: readUnknownField(stream, result, tag)

proc toJson*(message: Test1): JsonNode =
    result = newJObject()
    if hasa(message):
        result["a"] = %message.a
    if hase(message):
        result["e"] = %($message.e)

proc serialize*(message: Test1): string =
    let
        ss = newStringStream()
    writeTest1(ss, message)
    result = ss.data

proc newTest1*(data: string): Test1 =
    let
        ss = newStringStream(data)
    result = readTest1(ss)

proc newTest1*(data: seq[byte]): Test1 =
    let
        ss = newStringStream(cast[string](data))
    result = readTest1(ss)


