import endians
import intsets
import std/json
import macros
import streams
import strutils

export streams

const
    MaximumVarintBytes = 10
    WireTypeBits = 3
    WireTypeMask = (1 shl WireTypeBits) - 1

type
    Tag* = distinct uint32

    ParseError* = object of Exception

    InvalidFieldNumberError* = object of ParseError

    UnexpectedWireTypeError* = object of ParseError

    WireType* {.pure.} = enum
        Varint = 0
        Fixed64 = 1
        LengthDelimited = 2
        StartGroup = 3
        EndGroup = 4
        Fixed32 = 5

    FieldType* {.pure.} = enum
        Double = 1
        Float
        Int64
        UInt64
        Int32
        Fixed64
        Fixed32
        Bool
        String
        Group
        Message
        Bytes
        UInt32
        Enum
        SFixed32
        SFixed64
        SInt32
        SInt64

    UnknownField* = ref UnknownFieldObj
    UnknownFieldObj* = object
        fieldNumber: int
        case wiretype: WireType
        of WireType.Varint:
            vint: uint64
        of WireType.Fixed64:
            fixed64: uint64
        of WireType.LengthDelimited:
            data: string
        of WireType.Fixed32:
            fixed32: uint32
        else:
            discard

    Message* = ref MessageObj
    MessageObj* = object of RootObj
        hasField: IntSet
        unknownFields: seq[UnknownField]
        procs*: MessageProcs

    MessageProcs* = object
        readImpl*: proc (stream: Stream): Message
        writeImpl*: proc (stream: Stream, msg: Message)
        toJsonImpl*: proc (msg: Message): JsonNode
        fromJsonImpl*: proc (node: JsonNode): Message

proc wiretype*(ft: FieldType): WireType =
    case ft
    of FieldType.Double: result = WireType.Fixed64
    of FieldType.Float: result = WireType.Fixed32
    of FieldType.Int64: result = WireType.Varint
    of FieldType.UInt64: result = WireType.Varint
    of FieldType.Int32: result = WireType.Varint
    of FieldType.Fixed64: result = WireType.Fixed64
    of FieldType.Fixed32: result = WireType.Fixed32
    of FieldType.Bool: result = WireType.Varint
    of FieldType.String: result = WireType.LengthDelimited
    of FieldType.Group: result = WireType.LengthDelimited # ???
    of FieldType.Message: result = WireType.LengthDelimited
    of FieldType.Bytes: result = WireType.LengthDelimited
    of FieldType.UInt32: result = WireType.Varint
    of FieldType.Enum: result = WireType.Varint
    of FieldType.SFixed32: result = WireType.Fixed32
    of FieldType.SFixed64: result = WireType.Fixed64
    of FieldType.SInt32: result = WireType.Varint
    of FieldType.SInt64: result = WireType.Varint

proc isNumeric*(wiretype: WireType): bool =
    case wiretype
    of WireType.Varint: result = true
    of WireType.Fixed64: result = true
    of WireType.Fixed32: result = true
    else: result = false

proc isNumeric*(ft: FieldType): bool =
    result = isNumeric(wiretype(ft))

proc zigzagEncode*(n: int32): uint32 =
    let x = cast[uint32](n)
    let a = cast[int32](x shl 1)
    let b = -cast[int32](x shr 31)
    result = uint32(a xor b)

proc zigzagDecode*(n: uint32): int32 =
    let a = int32(n shr 1)
    let b = -int32(n and 1)
    result = a xor b

proc zigzagEncode*(n: int64): uint64 =
    let x = cast[uint64](n)
    let a = cast[int64](x shl 1)
    let b = -cast[int64](x shr 63)
    result = uint64(a xor b)

proc zigzagDecode*(n: uint64): int64 =
    let a = int64(n shr 1)
    let b = -int64(n and 1)
    result = a xor b

template makeTag*(fieldNumber: int, wireType: WireType): Tag =
    ((fieldNumber shl 3).uint32 or wireType.uint32).Tag

template wireType*(tag: Tag): WireType =
    (tag.uint32 and WireTypeMask).WireType

template fieldNumber*(tag: Tag): int =
    (tag.uint32 shr 3).int

proc protoReadByte(stream: Stream): byte =
    result = readInt8(stream).byte

proc protoWriteByte(stream: Stream, b: byte) =
    var x: byte
    shallowCopy(x, b)
    writeData(stream, addr(x), sizeof(x))

proc readVarint*(stream: Stream): uint64 =
    var
        count = 0

    result = 0

    while true:
        if count == MaximumVarintBytes:
            raise newException(Exception, "invalid varint (<= 10 bytes)")

        let b = protoReadByte(stream)

        result = result or ((b.uint64 and 0x7f) shl (7 * count))

        inc(count)

        if (b and 0x80) == 0:
            break

proc writeVarint*(stream: Stream, n: uint64) =
    var value = n
    while value >= 0x80'u64:
        protoWriteByte(stream, (value or 0x80).byte)
        value = value shr 7
    protoWriteByte(stream, value.byte)

proc writeTag*(stream: Stream, tag: Tag) =
    writeVarint(stream, tag.uint32)

proc writeTag*(stream: Stream, fieldNumber: int, wireType: WireType) =
    writeTag(stream, makeTag(fieldNumber, wireType))

proc readTag*(stream: Stream): Tag =
    result = readVarint(stream).Tag

proc protoWriteInt32*(stream: Stream, n: int32) =
    writeVarint(stream, n.uint64)

proc protoWriteInt32*(stream: Stream, n: int32, fieldNumber: int) =
    writeTag(stream, fieldNumber, WireType.Varint)
    protoWriteInt32(stream, n)

proc protoReadInt32*(stream: Stream): int32 =
    result = readVarint(stream).int32

proc protoWriteSInt32*(stream: Stream, n: int32) =
    writeVarint(stream, zigzagEncode(n))

proc protoWriteSInt32*(stream: Stream, n: int32, fieldNumber: int) =
    writeTag(stream, fieldNumber, WireType.Varint)
    writeVarint(stream, zigzagEncode(n))

proc protoReadSInt32*(stream: Stream): int32 =
    result = zigzagDecode(readVarint(stream).uint32)

proc protoWriteUInt32*(stream: Stream, n: uint32) =
    writeVarint(stream, n)

proc protoWriteUInt32*(stream: Stream, n: uint32, fieldNumber: int) =
    writeTag(stream, fieldNumber, WireType.Varint)
    writeVarint(stream, n)

proc protoReadUInt32*(stream: Stream): uint32 =
    result = readVarint(stream).uint32

proc protoWriteInt64*(stream: Stream, n: int64) =
    writeVarint(stream, n.uint64)

proc protoWriteInt64*(stream: Stream, n: int64, fieldNumber: int) =
    writeTag(stream, fieldNumber, WireType.Varint)
    writeVarint(stream, n.uint64)

proc protoReadInt64*(stream: Stream): int64 =
    result = readVarint(stream).int64

proc protoWriteSInt64*(stream: Stream, n: int64) =
    writeVarint(stream, zigzagEncode(n))

proc protoWriteSInt64*(stream: Stream, n: int64, fieldNumber: int) =
    writeTag(stream, fieldNumber, WireType.Varint)
    writeVarint(stream, zigzagEncode(n))

proc protoReadSInt64*(stream: Stream): int64 =
    result = zigzagDecode(readVarint(stream))

proc protoWriteUInt64*(stream: Stream, n: uint64) =
    writeVarint(stream, n)

proc protoWriteUInt64*(stream: Stream, n: uint64, fieldNumber: int) =
    writeTag(stream, fieldNumber, WireType.Varint)
    writeVarint(stream, n)

proc protoReadUInt64*(stream: Stream): uint64 =
    result = readVarint(stream)

proc protoWriteBool*(stream: Stream, value: bool) =
    writeVarint(stream, value.uint32)

proc protoWriteBool*(stream: Stream, n: bool, fieldNumber: int) =
    writeTag(stream, fieldNumber, WireType.Varint)
    writeVarint(stream, n.uint32)

proc protoReadBool*(stream: Stream): bool =
    result = readVarint(stream).bool

proc protoWriteFixed64*(stream: Stream, value: uint64) =
    var
        input = value
        output: uint64

    littleEndian64(addr(output), addr(input))

    write(stream, output)

proc protoWriteFixed64*(stream: Stream, n: uint64, fieldNumber: int) =
    writeTag(stream, fieldNumber, WireType.Fixed64)
    protoWriteFixed64(stream, n)

proc protoReadFixed64*(stream: Stream): uint64 =
    var tmp: uint64
    if readData(stream, addr(tmp), sizeof(tmp)) != sizeof(tmp):
        raise newException(IOError, "cannot read from stream")
    littleEndian64(addr(result), addr(tmp))

proc protoWriteSFixed64*(stream: Stream, value: int64) =
    protoWriteFixed64(stream, cast[uint64](value))

proc protoWriteSFixed64*(stream: Stream, value: int64, fieldNumber: int) =
    writeTag(stream, fieldNumber, WireType.Fixed64)
    protoWriteSFixed64(stream, value)

proc protoReadSFixed64*(stream: Stream): int64 =
    result = cast[int64](protoReadFixed64(stream))

proc protoWriteDouble*(stream: Stream, value: float64) =
    var
        input = value
        output: float64

    littleEndian64(addr(output), addr(input))

    write(stream, output)

proc protoWriteDouble*(stream: Stream, value: float64, fieldNumber: int) =
    writeTag(stream, fieldNumber, WireType.Fixed64)
    protoWriteDouble(stream, value)

proc protoReadDouble*(stream: Stream): float64 =
    var tmp: uint64
    if readData(stream, addr(tmp), sizeof(tmp)) != sizeof(tmp):
        raise newException(IOError, "cannot read from stream")
    littleEndian64(addr(result), addr(tmp))

proc protoWriteFixed32*(stream: Stream, value: uint32) =
    var
        input = value
        output: uint32

    littleEndian32(addr(output), addr(input))

    write(stream, output)

proc protoWriteFixed32*(stream: Stream, value: uint32, fieldNumber: int) =
    writeTag(stream, fieldNumber, WireType.Fixed32)
    protoWriteFixed32(stream, value)

proc protoReadFixed32*(stream: Stream): uint32 =
    var tmp: uint32
    if readData(stream, addr(tmp), sizeof(tmp)) != sizeof(tmp):
        raise newException(IOError, "cannot read from stream")
    littleEndian32(addr(result), addr(tmp))

proc protoWriteSFixed32*(stream: Stream, value: int32) =
    protoWriteFixed32(stream, cast[uint32](value))

proc protoWriteSFixed32*(stream: Stream, value: int32, fieldNumber: int) =
    writeTag(stream, fieldNumber, WireType.Fixed32)
    protoWriteSFixed32(stream, value)

proc protoReadSFixed32*(stream: Stream): int32 =
    result = cast[int32](protoReadFixed32(stream))

proc protoWriteFloat*(stream: Stream, value: float32) =
    var
        input = value
        output: float32

    littleEndian32(addr(output), addr(input))

    write(stream, output)

proc protoWriteFloat*(stream: Stream, value: float32, fieldNumber: int) =
    writeTag(stream, fieldNumber, WireType.Fixed32)
    protoWriteFloat(stream, value)

proc protoReadFloat*(stream: Stream): float32 =
    var tmp: float32
    if readData(stream, addr(tmp), sizeof(tmp)) != sizeof(tmp):
        raise newException(IOError, "cannot read from stream")
    littleEndian32(addr(result), addr(tmp))

proc protoWriteString*(stream: Stream, s: string) =
    protoWriteUInt64(stream, len(s).uint64)
    write(stream, s)

proc protoWriteString*(stream: Stream, s: string, fieldNumber: int) =
    writeTag(stream, fieldNumber, WireType.LengthDelimited)
    protoWriteString(stream, s)

proc protoWriteBytes*(stream: Stream, bytes: seq[byte], fieldNumber: int) =
    var bytes = bytes
    writeTag(stream, fieldNumber, WireType.LengthDelimited)
    protoWriteUInt64(stream, len(bytes).uint64)
    if len(bytes) > 0:
        writeData(stream, addr(bytes[0]), len(bytes))

proc safeReadStr*(stream: Stream, size: int): string =
    result = newString(size)
    if readData(stream, addr(result[0]), size) != size:
        raise newException(IOError, "cannot read from stream")

proc protoReadString*(stream: Stream): string =
    let size = int(protoReadUInt64(stream))
    result = safeReadStr(stream, size)

proc protoReadBytes*(stream: Stream): seq[byte] =
    let size = int(protoReadUInt64(stream))
    newSeq(result, size)
    if size == 0:
        return
    if readData(stream, addr(result[0]), size) != size:
        raise newException(IOError, "cannot read from stream")

proc protoReadEnum*[T](stream: Stream): T =
    result = T(protoReadUInt32(stream))

proc protoWriteEnum*[T](stream: Stream, value: T) =
    protoWriteUInt32(stream, uint32(value))

proc protoWriteEnum*[T](stream: Stream, value: T, fieldNumber: int) =
    writeTag(stream, fieldNumber, WireType.Varint)
    protoWriteUInt32(stream, uint32(value))

proc sizeOfVarint[T](value: T): uint64 =
    var tmp = uint64(value)
    while tmp >= 0x80'u64:
        tmp = tmp shr 7
        inc(result)
    inc(result)

proc packedFieldSize*[T](values: seq[T], fieldtype: FieldType): uint64 =
    case fieldtype
    of FieldType.Fixed64, FieldType.SFixed64, FieldType.Double:
        result = uint64(len(values)) * 8
    of FieldType.Fixed32, FieldType.SFixed32, FieldType.Float:
        result = uint64(len(values)) * 4
    of FieldType.Int64, FieldType.UInt64, FieldType.Int32, FieldType.Bool,
       FieldType.UInt32, FieldType.Enum:
        for value in values:
            result += sizeOfVarint(value)
    of FieldType.SInt32:
        for value in values:
            result += sizeOfVarint(zigzagEncode(int32(value)))
    of FieldType.SInt64:
        for value in values:
            result += sizeOfVarint(zigzagEncode(int64(value)))
    else:
        raise newException(Exception, "invalid fieldtype")

proc sizeOfLengthDelimited*(size: uint64): uint64 =
    result = size + sizeOfVarint(size)

proc sizeOfString*(s: string): uint64 =
    result = sizeOfVarint(len(s).uint64) + len(s).uint64

proc sizeOfBytes*(bytes: seq[byte]): uint64 =
    result = sizeOfLengthDelimited(uint64(len(bytes)))

proc sizeOfDouble*(value: float64): uint64 =
    result = 8

proc sizeOfFloat*(value: float32): uint64 =
    result = 4

proc sizeOfInt64*(value: int64): uint64 =
    result = sizeOfVarint(value)

proc sizeOfUInt64*(value: uint64): uint64 =
    result = sizeOfVarint(value)

proc sizeOfInt32*(value: int32): uint64 =
    result = sizeOfVarint(value)

proc sizeOfFixed64*(value: uint64): uint64 =
    result = 8

proc sizeOfFixed32*(value: uint32): uint64 =
    result = 4

proc sizeOfBool*(value: bool): uint64 =
    result = sizeOfVarint(value)

proc sizeOfUInt32*(value: uint32): uint64 =
    result = sizeOfVarint(value)

proc sizeOfSFixed32*(value: int32): uint64 =
    result = 4

proc sizeOfSFixed64*(value: int64): uint64 =
    result = 8

proc sizeOfSInt32*(value: int32): uint64 =
    result = sizeOfVarint(zigzagEncode(value))

proc sizeOfSInt64*(value: int64): uint64 =
    result = sizeOfVarint(zigzagEncode(value))

proc sizeOfEnum*[T](value: T): uint64 =
    result = sizeOfUInt32(value.uint32)

proc sizeOfTag*(fieldNumber: int, wiretype: WireType): uint64 =
    result = sizeOfUInt32(uint32(makeTag(fieldNumber, wiretype)))

proc skipField*(stream: Stream, wiretype: WireType) =
    case wiretype
    of WireType.Varint:
        discard readVarint(stream)
    of WireType.Fixed64:
        discard protoReadFixed64(stream)
    of WireType.Fixed32:
        discard protoReadFixed32(stream)
    of WireType.LengthDelimited:
        let size = readVarint(stream)
        discard safeReadStr(stream, int(size))
    else:
        raise newException(Exception, "unsupported wiretype: " & $wiretype)

proc expectWireType*(actual: WireType, expected: varargs[WireType]) =
    for exp in expected:
        if actual == exp:
            return
    let message = "Got wiretype " & $actual & " but expected: " &
        join(expected, ", ")
    raise newException(UnexpectedWireTypeError, message)

macro writeMessage*(stream: Stream, message: typed, fieldNumber: int): typed =
    ## Write a message to a stream with tag and length.
    let t = getTypeInst(message)
    result = newStmtList(
        newCall(
            ident("writeTag"),
            stream,
            fieldNumber,
            newDotExpr(ident("WireType"), ident("LengthDelimited"))
        ),
        newCall(
            ident("writeVarint"),
            stream,
            newCall(ident("sizeOf" & $t), message)
        ),
        newCall(
            ident("write" & $t),
            stream,
            message
        )
    )

proc excl*(s: var IntSet, values: openArray[int]) =
    ## Exclude multiple values from an IntSet.
    for value in values:
        excl(s, value)

proc readLengthDelimited*(stream: Stream): string =
    let size = int(readVarint(stream))
    result = safeReadStr(stream, size)

proc readUnknownField*(stream: Stream, tag: Tag,
                       fields: var seq[UnknownField]) =
    var field: UnknownField

    new(field)
    field.fieldNumber = fieldNumber(tag)
    field.wireType = wiretype(tag)

    case field.wiretype
    of WireType.Varint:
        field.vint = readVarint(stream)
    of WireType.Fixed64:
        field.fixed64 = protoReadFixed64(stream)
    of WireType.Fixed32:
        field.fixed32 = protoReadFixed32(stream)
    of WireType.LengthDelimited:
        let size = readVarint(stream)
        field.data = safeReadStr(stream, int(size))
    else:
        raise newException(Exception, "unsupported wiretype: " & $field.wiretype)

    add(fields, field)

proc readUnknownField*(stream: Stream, message: Message, tag: Tag) =
    readUnknownField(stream, tag, message.unknownFields)

proc writeUnknownFields*(stream: Stream, fields: seq[UnknownField]) =
    for field in fields:
        case field.wiretype
        of WireType.Varint:
            writeTag(stream, field.fieldNumber, field.wireType)
            writeVarint(stream, field.vint)
        of WireType.Fixed64:
            protoWriteFixed64(stream, field.fixed64, field.fieldNumber)
        of WireType.Fixed32:
            protoWriteFixed32(stream, field.fixed32, field.fieldNumber)
        of WireType.LengthDelimited:
            protoWriteString(stream, field.data, field.fieldNumber)
        else:
            raise newException(Exception, "unsupported wiretype: " & $field.wiretype)

proc writeUnknownFields*(stream: Stream, message: Message) =
    writeUnknownFields(stream, message.unknownFields)

proc discardUnknownFields*[T](message: T) =
    message.unknownFields = @[]

proc sizeOfUnknownField*(field: UnknownField): uint64 =
    result = sizeOfTag(field.fieldNumber, field.wiretype)
    case field.wiretype
    of WireType.Varint:
        result = result + sizeOfVarint(field.vint)
    of WireType.Fixed64:
        result = result + 8
    of WireType.Fixed32:
        result = result + 4
    of WireType.LengthDelimited:
        result = result + sizeOfLengthDelimited(uint64(len(field.data)))
    else:
        raise newException(Exception, "unsupported wiretype: " & $field.wiretype)

proc sizeOfUnknownFields*(message: Message): uint64 =
    for field in message.unknownFields:
        result = result + sizeOfUnknownField(field)

proc initMessage*(message: var MessageObj) =
    message.hasField = initIntSet()
    message.unknownFields = @[]

proc hasField*(message: Message, fieldNumber: int): bool =
    contains(message.hasField, fieldNumber)

proc hasFields*(message: Message, fieldNumbers: openArray[int]): bool =
    for fieldNumber in fieldNumbers:
        if contains(message.hasField, fieldNumber):
            return true

proc clearFields*(message: Message, fieldNumbers: openArray[int]) =
    excl(message.hasField, fieldNumbers)

proc setField*(message: Message, fieldNumber: int) =
    incl(message.hasField, fieldNumber)
