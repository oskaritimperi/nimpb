type
    bytes* = distinct string

    # int32 # varint, no zigzag
    # int64 # varint, no zigzag
    # uint32 # varint, no zigzag
    # uint64 # varint, no zigzag
    # fixed32 # 32-bit uint
    # fixed64 # 64-bit uint
    # sfixed32 # 32-bit int
    # sfixed64 # 64-bit int
    # sint32 # varint, zigzag
    # sint64 # varint, zigzag
    # float32 # fixed32
    # float64 # fixed64

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
