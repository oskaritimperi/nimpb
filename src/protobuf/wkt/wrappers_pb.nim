# Generated by protoc_gen_nim. Do not edit!

import intsets

import protobuf/stream
import protobuf/types

type
    google_protobuf_DoubleValue* = ref google_protobuf_DoubleValueObj
    google_protobuf_DoubleValueObj* = object of RootObj
        hasField: IntSet
        value: float64
    google_protobuf_FloatValue* = ref google_protobuf_FloatValueObj
    google_protobuf_FloatValueObj* = object of RootObj
        hasField: IntSet
        value: float32
    google_protobuf_Int64Value* = ref google_protobuf_Int64ValueObj
    google_protobuf_Int64ValueObj* = object of RootObj
        hasField: IntSet
        value: int64
    google_protobuf_UInt64Value* = ref google_protobuf_UInt64ValueObj
    google_protobuf_UInt64ValueObj* = object of RootObj
        hasField: IntSet
        value: uint64
    google_protobuf_Int32Value* = ref google_protobuf_Int32ValueObj
    google_protobuf_Int32ValueObj* = object of RootObj
        hasField: IntSet
        value: int32
    google_protobuf_UInt32Value* = ref google_protobuf_UInt32ValueObj
    google_protobuf_UInt32ValueObj* = object of RootObj
        hasField: IntSet
        value: uint32
    google_protobuf_BoolValue* = ref google_protobuf_BoolValueObj
    google_protobuf_BoolValueObj* = object of RootObj
        hasField: IntSet
        value: bool
    google_protobuf_StringValue* = ref google_protobuf_StringValueObj
    google_protobuf_StringValueObj* = object of RootObj
        hasField: IntSet
        value: string
    google_protobuf_BytesValue* = ref google_protobuf_BytesValueObj
    google_protobuf_BytesValueObj* = object of RootObj
        hasField: IntSet
        value: bytes

proc newgoogle_protobuf_Int32Value*(): google_protobuf_Int32Value
proc writegoogle_protobuf_Int32Value*(stream: ProtobufStream, message: google_protobuf_Int32Value)
proc readgoogle_protobuf_Int32Value*(stream: ProtobufStream): google_protobuf_Int32Value
proc sizeOfgoogle_protobuf_Int32Value*(message: google_protobuf_Int32Value): uint64

proc newgoogle_protobuf_Int64Value*(): google_protobuf_Int64Value
proc writegoogle_protobuf_Int64Value*(stream: ProtobufStream, message: google_protobuf_Int64Value)
proc readgoogle_protobuf_Int64Value*(stream: ProtobufStream): google_protobuf_Int64Value
proc sizeOfgoogle_protobuf_Int64Value*(message: google_protobuf_Int64Value): uint64

proc newgoogle_protobuf_DoubleValue*(): google_protobuf_DoubleValue
proc writegoogle_protobuf_DoubleValue*(stream: ProtobufStream, message: google_protobuf_DoubleValue)
proc readgoogle_protobuf_DoubleValue*(stream: ProtobufStream): google_protobuf_DoubleValue
proc sizeOfgoogle_protobuf_DoubleValue*(message: google_protobuf_DoubleValue): uint64

proc newgoogle_protobuf_StringValue*(): google_protobuf_StringValue
proc writegoogle_protobuf_StringValue*(stream: ProtobufStream, message: google_protobuf_StringValue)
proc readgoogle_protobuf_StringValue*(stream: ProtobufStream): google_protobuf_StringValue
proc sizeOfgoogle_protobuf_StringValue*(message: google_protobuf_StringValue): uint64

proc newgoogle_protobuf_BoolValue*(): google_protobuf_BoolValue
proc writegoogle_protobuf_BoolValue*(stream: ProtobufStream, message: google_protobuf_BoolValue)
proc readgoogle_protobuf_BoolValue*(stream: ProtobufStream): google_protobuf_BoolValue
proc sizeOfgoogle_protobuf_BoolValue*(message: google_protobuf_BoolValue): uint64

proc newgoogle_protobuf_BytesValue*(): google_protobuf_BytesValue
proc writegoogle_protobuf_BytesValue*(stream: ProtobufStream, message: google_protobuf_BytesValue)
proc readgoogle_protobuf_BytesValue*(stream: ProtobufStream): google_protobuf_BytesValue
proc sizeOfgoogle_protobuf_BytesValue*(message: google_protobuf_BytesValue): uint64

proc newgoogle_protobuf_FloatValue*(): google_protobuf_FloatValue
proc writegoogle_protobuf_FloatValue*(stream: ProtobufStream, message: google_protobuf_FloatValue)
proc readgoogle_protobuf_FloatValue*(stream: ProtobufStream): google_protobuf_FloatValue
proc sizeOfgoogle_protobuf_FloatValue*(message: google_protobuf_FloatValue): uint64

proc newgoogle_protobuf_UInt64Value*(): google_protobuf_UInt64Value
proc writegoogle_protobuf_UInt64Value*(stream: ProtobufStream, message: google_protobuf_UInt64Value)
proc readgoogle_protobuf_UInt64Value*(stream: ProtobufStream): google_protobuf_UInt64Value
proc sizeOfgoogle_protobuf_UInt64Value*(message: google_protobuf_UInt64Value): uint64

proc newgoogle_protobuf_UInt32Value*(): google_protobuf_UInt32Value
proc writegoogle_protobuf_UInt32Value*(stream: ProtobufStream, message: google_protobuf_UInt32Value)
proc readgoogle_protobuf_UInt32Value*(stream: ProtobufStream): google_protobuf_UInt32Value
proc sizeOfgoogle_protobuf_UInt32Value*(message: google_protobuf_UInt32Value): uint64

proc newgoogle_protobuf_Int32Value*(): google_protobuf_Int32Value =
    new(result)
    result.hasField = initIntSet()
    result.value = 0

proc clearvalue*(message: google_protobuf_Int32Value) =
    message.value = 0
    excl(message.hasField, 1)

proc hasvalue*(message: google_protobuf_Int32Value): bool =
    result = contains(message.hasField, 1)

proc setvalue*(message: google_protobuf_Int32Value, value: int32) =
    message.value = value
    incl(message.hasField, 1)

proc value*(message: google_protobuf_Int32Value): int32 {.inline.} =
    message.value

proc `value=`*(message: google_protobuf_Int32Value, value: int32) {.inline.} =
    setvalue(message, value)

proc sizeOfgoogle_protobuf_Int32Value*(message: google_protobuf_Int32Value): uint64 =
    if hasvalue(message):
        let
            sizeOfField = sizeOfInt32(message.value)
            sizeOfTag = sizeOfUInt32(uint32(makeTag(1, WireType.Varint)))
        result = result + sizeOfField + sizeOfTag

proc writegoogle_protobuf_Int32Value*(stream: ProtobufStream, message: google_protobuf_Int32Value) =
    if hasvalue(message):
        writeTag(stream, 1, WireType.Varint)
        writeInt32(stream, message.value)

proc readgoogle_protobuf_Int32Value*(stream: ProtobufStream): google_protobuf_Int32Value =
    result = newgoogle_protobuf_Int32Value()
    while not atEnd(stream):
        let
            tag = readTag(stream)
            wireType = getTagWireType(tag)
        case getTagFieldNumber(tag)
        of 1:
            setvalue(result, readInt32(stream))
        else: skipField(stream, wireType)

proc serialize*(message: google_protobuf_Int32Value): string =
    let
        ss = newStringStream()
        pbs = newProtobufStream(ss)
    writegoogle_protobuf_Int32Value(pbs, message)
    result = ss.data

proc newgoogle_protobuf_Int32Value*(data: string): google_protobuf_Int32Value =
    let
        ss = newStringStream(data)
        pbs = newProtobufStream(ss)
    result = readgoogle_protobuf_Int32Value(pbs)


proc newgoogle_protobuf_Int64Value*(): google_protobuf_Int64Value =
    new(result)
    result.hasField = initIntSet()
    result.value = 0

proc clearvalue*(message: google_protobuf_Int64Value) =
    message.value = 0
    excl(message.hasField, 1)

proc hasvalue*(message: google_protobuf_Int64Value): bool =
    result = contains(message.hasField, 1)

proc setvalue*(message: google_protobuf_Int64Value, value: int64) =
    message.value = value
    incl(message.hasField, 1)

proc value*(message: google_protobuf_Int64Value): int64 {.inline.} =
    message.value

proc `value=`*(message: google_protobuf_Int64Value, value: int64) {.inline.} =
    setvalue(message, value)

proc sizeOfgoogle_protobuf_Int64Value*(message: google_protobuf_Int64Value): uint64 =
    if hasvalue(message):
        let
            sizeOfField = sizeOfInt64(message.value)
            sizeOfTag = sizeOfUInt32(uint32(makeTag(1, WireType.Varint)))
        result = result + sizeOfField + sizeOfTag

proc writegoogle_protobuf_Int64Value*(stream: ProtobufStream, message: google_protobuf_Int64Value) =
    if hasvalue(message):
        writeTag(stream, 1, WireType.Varint)
        writeInt64(stream, message.value)

proc readgoogle_protobuf_Int64Value*(stream: ProtobufStream): google_protobuf_Int64Value =
    result = newgoogle_protobuf_Int64Value()
    while not atEnd(stream):
        let
            tag = readTag(stream)
            wireType = getTagWireType(tag)
        case getTagFieldNumber(tag)
        of 1:
            setvalue(result, readInt64(stream))
        else: skipField(stream, wireType)

proc serialize*(message: google_protobuf_Int64Value): string =
    let
        ss = newStringStream()
        pbs = newProtobufStream(ss)
    writegoogle_protobuf_Int64Value(pbs, message)
    result = ss.data

proc newgoogle_protobuf_Int64Value*(data: string): google_protobuf_Int64Value =
    let
        ss = newStringStream(data)
        pbs = newProtobufStream(ss)
    result = readgoogle_protobuf_Int64Value(pbs)


proc newgoogle_protobuf_DoubleValue*(): google_protobuf_DoubleValue =
    new(result)
    result.hasField = initIntSet()
    result.value = 0

proc clearvalue*(message: google_protobuf_DoubleValue) =
    message.value = 0
    excl(message.hasField, 1)

proc hasvalue*(message: google_protobuf_DoubleValue): bool =
    result = contains(message.hasField, 1)

proc setvalue*(message: google_protobuf_DoubleValue, value: float64) =
    message.value = value
    incl(message.hasField, 1)

proc value*(message: google_protobuf_DoubleValue): float64 {.inline.} =
    message.value

proc `value=`*(message: google_protobuf_DoubleValue, value: float64) {.inline.} =
    setvalue(message, value)

proc sizeOfgoogle_protobuf_DoubleValue*(message: google_protobuf_DoubleValue): uint64 =
    if hasvalue(message):
        let
            sizeOfField = sizeOfDouble(message.value)
            sizeOfTag = sizeOfUInt32(uint32(makeTag(1, WireType.Fixed64)))
        result = result + sizeOfField + sizeOfTag

proc writegoogle_protobuf_DoubleValue*(stream: ProtobufStream, message: google_protobuf_DoubleValue) =
    if hasvalue(message):
        writeTag(stream, 1, WireType.Fixed64)
        writeDouble(stream, message.value)

proc readgoogle_protobuf_DoubleValue*(stream: ProtobufStream): google_protobuf_DoubleValue =
    result = newgoogle_protobuf_DoubleValue()
    while not atEnd(stream):
        let
            tag = readTag(stream)
            wireType = getTagWireType(tag)
        case getTagFieldNumber(tag)
        of 1:
            setvalue(result, readDouble(stream))
        else: skipField(stream, wireType)

proc serialize*(message: google_protobuf_DoubleValue): string =
    let
        ss = newStringStream()
        pbs = newProtobufStream(ss)
    writegoogle_protobuf_DoubleValue(pbs, message)
    result = ss.data

proc newgoogle_protobuf_DoubleValue*(data: string): google_protobuf_DoubleValue =
    let
        ss = newStringStream(data)
        pbs = newProtobufStream(ss)
    result = readgoogle_protobuf_DoubleValue(pbs)


proc newgoogle_protobuf_StringValue*(): google_protobuf_StringValue =
    new(result)
    result.hasField = initIntSet()
    result.value = ""

proc clearvalue*(message: google_protobuf_StringValue) =
    message.value = ""
    excl(message.hasField, 1)

proc hasvalue*(message: google_protobuf_StringValue): bool =
    result = contains(message.hasField, 1)

proc setvalue*(message: google_protobuf_StringValue, value: string) =
    message.value = value
    incl(message.hasField, 1)

proc value*(message: google_protobuf_StringValue): string {.inline.} =
    message.value

proc `value=`*(message: google_protobuf_StringValue, value: string) {.inline.} =
    setvalue(message, value)

proc sizeOfgoogle_protobuf_StringValue*(message: google_protobuf_StringValue): uint64 =
    if hasvalue(message):
        let
            sizeOfField = sizeOfString(message.value)
            sizeOfTag = sizeOfUInt32(uint32(makeTag(1, WireType.LengthDelimited)))
        result = result + sizeOfField + sizeOfTag

proc writegoogle_protobuf_StringValue*(stream: ProtobufStream, message: google_protobuf_StringValue) =
    if hasvalue(message):
        writeTag(stream, 1, WireType.LengthDelimited)
        writeString(stream, message.value)

proc readgoogle_protobuf_StringValue*(stream: ProtobufStream): google_protobuf_StringValue =
    result = newgoogle_protobuf_StringValue()
    while not atEnd(stream):
        let
            tag = readTag(stream)
            wireType = getTagWireType(tag)
        case getTagFieldNumber(tag)
        of 1:
            setvalue(result, readString(stream))
        else: skipField(stream, wireType)

proc serialize*(message: google_protobuf_StringValue): string =
    let
        ss = newStringStream()
        pbs = newProtobufStream(ss)
    writegoogle_protobuf_StringValue(pbs, message)
    result = ss.data

proc newgoogle_protobuf_StringValue*(data: string): google_protobuf_StringValue =
    let
        ss = newStringStream(data)
        pbs = newProtobufStream(ss)
    result = readgoogle_protobuf_StringValue(pbs)


proc newgoogle_protobuf_BoolValue*(): google_protobuf_BoolValue =
    new(result)
    result.hasField = initIntSet()
    result.value = false

proc clearvalue*(message: google_protobuf_BoolValue) =
    message.value = false
    excl(message.hasField, 1)

proc hasvalue*(message: google_protobuf_BoolValue): bool =
    result = contains(message.hasField, 1)

proc setvalue*(message: google_protobuf_BoolValue, value: bool) =
    message.value = value
    incl(message.hasField, 1)

proc value*(message: google_protobuf_BoolValue): bool {.inline.} =
    message.value

proc `value=`*(message: google_protobuf_BoolValue, value: bool) {.inline.} =
    setvalue(message, value)

proc sizeOfgoogle_protobuf_BoolValue*(message: google_protobuf_BoolValue): uint64 =
    if hasvalue(message):
        let
            sizeOfField = sizeOfBool(message.value)
            sizeOfTag = sizeOfUInt32(uint32(makeTag(1, WireType.Varint)))
        result = result + sizeOfField + sizeOfTag

proc writegoogle_protobuf_BoolValue*(stream: ProtobufStream, message: google_protobuf_BoolValue) =
    if hasvalue(message):
        writeTag(stream, 1, WireType.Varint)
        writeBool(stream, message.value)

proc readgoogle_protobuf_BoolValue*(stream: ProtobufStream): google_protobuf_BoolValue =
    result = newgoogle_protobuf_BoolValue()
    while not atEnd(stream):
        let
            tag = readTag(stream)
            wireType = getTagWireType(tag)
        case getTagFieldNumber(tag)
        of 1:
            setvalue(result, readBool(stream))
        else: skipField(stream, wireType)

proc serialize*(message: google_protobuf_BoolValue): string =
    let
        ss = newStringStream()
        pbs = newProtobufStream(ss)
    writegoogle_protobuf_BoolValue(pbs, message)
    result = ss.data

proc newgoogle_protobuf_BoolValue*(data: string): google_protobuf_BoolValue =
    let
        ss = newStringStream(data)
        pbs = newProtobufStream(ss)
    result = readgoogle_protobuf_BoolValue(pbs)


proc newgoogle_protobuf_BytesValue*(): google_protobuf_BytesValue =
    new(result)
    result.hasField = initIntSet()
    result.value = bytes("")

proc clearvalue*(message: google_protobuf_BytesValue) =
    message.value = bytes("")
    excl(message.hasField, 1)

proc hasvalue*(message: google_protobuf_BytesValue): bool =
    result = contains(message.hasField, 1)

proc setvalue*(message: google_protobuf_BytesValue, value: bytes) =
    message.value = value
    incl(message.hasField, 1)

proc value*(message: google_protobuf_BytesValue): bytes {.inline.} =
    message.value

proc `value=`*(message: google_protobuf_BytesValue, value: bytes) {.inline.} =
    setvalue(message, value)

proc sizeOfgoogle_protobuf_BytesValue*(message: google_protobuf_BytesValue): uint64 =
    if hasvalue(message):
        let
            sizeOfField = sizeOfBytes(message.value)
            sizeOfTag = sizeOfUInt32(uint32(makeTag(1, WireType.LengthDelimited)))
        result = result + sizeOfField + sizeOfTag

proc writegoogle_protobuf_BytesValue*(stream: ProtobufStream, message: google_protobuf_BytesValue) =
    if hasvalue(message):
        writeTag(stream, 1, WireType.LengthDelimited)
        writeBytes(stream, message.value)

proc readgoogle_protobuf_BytesValue*(stream: ProtobufStream): google_protobuf_BytesValue =
    result = newgoogle_protobuf_BytesValue()
    while not atEnd(stream):
        let
            tag = readTag(stream)
            wireType = getTagWireType(tag)
        case getTagFieldNumber(tag)
        of 1:
            setvalue(result, readBytes(stream))
        else: skipField(stream, wireType)

proc serialize*(message: google_protobuf_BytesValue): string =
    let
        ss = newStringStream()
        pbs = newProtobufStream(ss)
    writegoogle_protobuf_BytesValue(pbs, message)
    result = ss.data

proc newgoogle_protobuf_BytesValue*(data: string): google_protobuf_BytesValue =
    let
        ss = newStringStream(data)
        pbs = newProtobufStream(ss)
    result = readgoogle_protobuf_BytesValue(pbs)


proc newgoogle_protobuf_FloatValue*(): google_protobuf_FloatValue =
    new(result)
    result.hasField = initIntSet()
    result.value = 0

proc clearvalue*(message: google_protobuf_FloatValue) =
    message.value = 0
    excl(message.hasField, 1)

proc hasvalue*(message: google_protobuf_FloatValue): bool =
    result = contains(message.hasField, 1)

proc setvalue*(message: google_protobuf_FloatValue, value: float32) =
    message.value = value
    incl(message.hasField, 1)

proc value*(message: google_protobuf_FloatValue): float32 {.inline.} =
    message.value

proc `value=`*(message: google_protobuf_FloatValue, value: float32) {.inline.} =
    setvalue(message, value)

proc sizeOfgoogle_protobuf_FloatValue*(message: google_protobuf_FloatValue): uint64 =
    if hasvalue(message):
        let
            sizeOfField = sizeOfFloat(message.value)
            sizeOfTag = sizeOfUInt32(uint32(makeTag(1, WireType.Fixed32)))
        result = result + sizeOfField + sizeOfTag

proc writegoogle_protobuf_FloatValue*(stream: ProtobufStream, message: google_protobuf_FloatValue) =
    if hasvalue(message):
        writeTag(stream, 1, WireType.Fixed32)
        writeFloat(stream, message.value)

proc readgoogle_protobuf_FloatValue*(stream: ProtobufStream): google_protobuf_FloatValue =
    result = newgoogle_protobuf_FloatValue()
    while not atEnd(stream):
        let
            tag = readTag(stream)
            wireType = getTagWireType(tag)
        case getTagFieldNumber(tag)
        of 1:
            setvalue(result, readFloat(stream))
        else: skipField(stream, wireType)

proc serialize*(message: google_protobuf_FloatValue): string =
    let
        ss = newStringStream()
        pbs = newProtobufStream(ss)
    writegoogle_protobuf_FloatValue(pbs, message)
    result = ss.data

proc newgoogle_protobuf_FloatValue*(data: string): google_protobuf_FloatValue =
    let
        ss = newStringStream(data)
        pbs = newProtobufStream(ss)
    result = readgoogle_protobuf_FloatValue(pbs)


proc newgoogle_protobuf_UInt64Value*(): google_protobuf_UInt64Value =
    new(result)
    result.hasField = initIntSet()
    result.value = 0

proc clearvalue*(message: google_protobuf_UInt64Value) =
    message.value = 0
    excl(message.hasField, 1)

proc hasvalue*(message: google_protobuf_UInt64Value): bool =
    result = contains(message.hasField, 1)

proc setvalue*(message: google_protobuf_UInt64Value, value: uint64) =
    message.value = value
    incl(message.hasField, 1)

proc value*(message: google_protobuf_UInt64Value): uint64 {.inline.} =
    message.value

proc `value=`*(message: google_protobuf_UInt64Value, value: uint64) {.inline.} =
    setvalue(message, value)

proc sizeOfgoogle_protobuf_UInt64Value*(message: google_protobuf_UInt64Value): uint64 =
    if hasvalue(message):
        let
            sizeOfField = sizeOfUInt64(message.value)
            sizeOfTag = sizeOfUInt32(uint32(makeTag(1, WireType.Varint)))
        result = result + sizeOfField + sizeOfTag

proc writegoogle_protobuf_UInt64Value*(stream: ProtobufStream, message: google_protobuf_UInt64Value) =
    if hasvalue(message):
        writeTag(stream, 1, WireType.Varint)
        writeUInt64(stream, message.value)

proc readgoogle_protobuf_UInt64Value*(stream: ProtobufStream): google_protobuf_UInt64Value =
    result = newgoogle_protobuf_UInt64Value()
    while not atEnd(stream):
        let
            tag = readTag(stream)
            wireType = getTagWireType(tag)
        case getTagFieldNumber(tag)
        of 1:
            setvalue(result, readUInt64(stream))
        else: skipField(stream, wireType)

proc serialize*(message: google_protobuf_UInt64Value): string =
    let
        ss = newStringStream()
        pbs = newProtobufStream(ss)
    writegoogle_protobuf_UInt64Value(pbs, message)
    result = ss.data

proc newgoogle_protobuf_UInt64Value*(data: string): google_protobuf_UInt64Value =
    let
        ss = newStringStream(data)
        pbs = newProtobufStream(ss)
    result = readgoogle_protobuf_UInt64Value(pbs)


proc newgoogle_protobuf_UInt32Value*(): google_protobuf_UInt32Value =
    new(result)
    result.hasField = initIntSet()
    result.value = 0

proc clearvalue*(message: google_protobuf_UInt32Value) =
    message.value = 0
    excl(message.hasField, 1)

proc hasvalue*(message: google_protobuf_UInt32Value): bool =
    result = contains(message.hasField, 1)

proc setvalue*(message: google_protobuf_UInt32Value, value: uint32) =
    message.value = value
    incl(message.hasField, 1)

proc value*(message: google_protobuf_UInt32Value): uint32 {.inline.} =
    message.value

proc `value=`*(message: google_protobuf_UInt32Value, value: uint32) {.inline.} =
    setvalue(message, value)

proc sizeOfgoogle_protobuf_UInt32Value*(message: google_protobuf_UInt32Value): uint64 =
    if hasvalue(message):
        let
            sizeOfField = sizeOfUInt32(message.value)
            sizeOfTag = sizeOfUInt32(uint32(makeTag(1, WireType.Varint)))
        result = result + sizeOfField + sizeOfTag

proc writegoogle_protobuf_UInt32Value*(stream: ProtobufStream, message: google_protobuf_UInt32Value) =
    if hasvalue(message):
        writeTag(stream, 1, WireType.Varint)
        writeUInt32(stream, message.value)

proc readgoogle_protobuf_UInt32Value*(stream: ProtobufStream): google_protobuf_UInt32Value =
    result = newgoogle_protobuf_UInt32Value()
    while not atEnd(stream):
        let
            tag = readTag(stream)
            wireType = getTagWireType(tag)
        case getTagFieldNumber(tag)
        of 1:
            setvalue(result, readUInt32(stream))
        else: skipField(stream, wireType)

proc serialize*(message: google_protobuf_UInt32Value): string =
    let
        ss = newStringStream()
        pbs = newProtobufStream(ss)
    writegoogle_protobuf_UInt32Value(pbs, message)
    result = ss.data

proc newgoogle_protobuf_UInt32Value*(data: string): google_protobuf_UInt32Value =
    let
        ss = newStringStream(data)
        pbs = newProtobufStream(ss)
    result = readgoogle_protobuf_UInt32Value(pbs)


