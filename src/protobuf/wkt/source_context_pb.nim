# Generated by protoc_gen_nim. Do not edit!

import intsets

import protobuf/stream
import protobuf/types

type
    google_protobuf_SourceContext* = ref google_protobuf_SourceContextObj
    google_protobuf_SourceContextObj* = object of RootObj
        hasField: IntSet
        file_name: string

proc newgoogle_protobuf_SourceContext*(): google_protobuf_SourceContext
proc writegoogle_protobuf_SourceContext*(stream: ProtobufStream, message: google_protobuf_SourceContext)
proc readgoogle_protobuf_SourceContext*(stream: ProtobufStream): google_protobuf_SourceContext
proc sizeOfgoogle_protobuf_SourceContext*(message: google_protobuf_SourceContext): uint64

proc newgoogle_protobuf_SourceContext*(): google_protobuf_SourceContext =
    new(result)
    result.hasField = initIntSet()
    result.file_name = ""

proc clearfile_name*(message: google_protobuf_SourceContext) =
    message.file_name = ""
    excl(message.hasField, 1)

proc hasfile_name*(message: google_protobuf_SourceContext): bool =
    result = contains(message.hasField, 1)

proc setfile_name*(message: google_protobuf_SourceContext, value: string) =
    message.file_name = value
    incl(message.hasField, 1)

proc file_name*(message: google_protobuf_SourceContext): string {.inline.} =
    message.file_name

proc `file_name=`*(message: google_protobuf_SourceContext, value: string) {.inline.} =
    setfile_name(message, value)

proc sizeOfgoogle_protobuf_SourceContext*(message: google_protobuf_SourceContext): uint64 =
    if hasfile_name(message):
        let
            sizeOfField = sizeOfString(message.file_name)
            sizeOfTag = sizeOfUInt32(uint32(makeTag(1, WireType.LengthDelimited)))
        result = result + sizeOfField + sizeOfTag

proc writegoogle_protobuf_SourceContext*(stream: ProtobufStream, message: google_protobuf_SourceContext) =
    if hasfile_name(message):
        writeTag(stream, 1, WireType.LengthDelimited)
        writeString(stream, message.file_name)

proc readgoogle_protobuf_SourceContext*(stream: ProtobufStream): google_protobuf_SourceContext =
    result = newgoogle_protobuf_SourceContext()
    while not atEnd(stream):
        let
            tag = readTag(stream)
            wireType = getTagWireType(tag)
        case getTagFieldNumber(tag)
        of 1:
            setfile_name(result, readString(stream))
        else: skipField(stream, wireType)

proc serialize*(message: google_protobuf_SourceContext): string =
    let
        ss = newStringStream()
        pbs = newProtobufStream(ss)
    writegoogle_protobuf_SourceContext(pbs, message)
    result = ss.data

proc newgoogle_protobuf_SourceContext*(data: string): google_protobuf_SourceContext =
    let
        ss = newStringStream(data)
        pbs = newProtobufStream(ss)
    result = readgoogle_protobuf_SourceContext(pbs)


