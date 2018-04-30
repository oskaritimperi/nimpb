import json
import tables

import duration
import empty_pb
import field_mask
import struct
import timestamp
import wrappers

include any_pb
import utils

var
    typeRegistry = newTable[string, MessageProcs]()

proc registerType*(prefix, typeName: string, procs: MessageProcs) =
    ## Register message procs to the type registry.
    ##
    ## The type registry associates a type url with message procs. The type url
    ## is constructed from the prefix and typeName by joining them with a
    ## forward slash.
    typeRegistry[prefix & "/" & typeName] = procs

template registerType*(T: typedesc) =
    ## Register a type to the type registry.
    ##
    ## This is a convenience template around the registerType() proc. The prefix
    ## used is "type.googleapis.com".
    var procs = `T Procs`()
    registerType("type.googleapis.com", fullyQualifiedName(T), procs)

template registerType*(prefix: string, T: typedesc) =
    ## Register a type to the type registry with a custom prefix.
    var procs = `T Procs`()
    registerType(prefix, fullyQualifiedName(T), procs)

template pack*(msg: typed): google_protobuf_Any =
    ## Pack a message into an Any.
    var
        any = newgoogle_protobuf_Any()
    any.typeUrl = "type.googleapis.com/" & fullyQualifiedName(type(msg))
    any.value = cast[seq[byte]](serialize(msg))
    any

template pack*(msg: typed, prefix: string): google_protobuf_Any =
    ## Pack a message into an Any with a custom prefix.
    var
        any = newgoogle_protobuf_Any()
    any.typeUrl = prefix & "/" & fullyQualifiedName(type(msg))
    any.value = cast[seq[byte]](serialize(msg))
    any

proc unpack*(src: google_protobuf_Any): Message =
    ## Unpack an Any into a message based on the typeUrl of the Any.
    ##
    ## The typeUrl must exist in the type registry.
    if src.typeUrl notin typeRegistry:
        raise newException(KeyError, "unknown type url: " & src.typeUrl)

    let
        procs = typeRegistry[src.typeUrl]
        ss = newStringStream(cast[string](src.value))

    result = procs.readImpl(ss)

proc getTypenameFromTypeUrl*(typeUrl: string): string =
    ## Extract the type name from a type url.
    ##
    ## Returns the last slash delimited part of the type url.
    let slashIndex = rfind(typeUrl, '/')
    if slashIndex != -1:
        result = typeUrl[slashIndex+1..^1]
    else:
        result = typeUrl

proc toJson*(msg: google_protobuf_Any): JsonNode =
    ## Convert an Any into JSON.
    ##
    ## If the embedded message is a well known type, the conversion should
    ## succeed if the values in the message are valid.
    ##
    ## Otherwise, the type url of the embedded message has to be registered in
    ## the type registry, so that this procs knows how to convert the embedded
    ## message into JSON.
    result = newJObject()
    result["@type"] = %msg.typeUrl

    let typeName = getTypenameFromTypeUrl(msg.typeUrl)

    case typeName
    of "google.protobuf.Duration":
        let duration = newgoogle_protobuf_Duration(cast[string](msg.value))
        result["value"] = toJson(duration)
    of "google.protobuf.Empty":
        result["value"] = newJObject()
    of "google.protobuf.FieldMask":
        let mask = newgoogle_protobuf_FieldMask(cast[string](msg.value))
        result["value"] = toJson(mask)
    of "google.protobuf.Struct":
        let struct = newgoogle_protobuf_Struct(cast[string](msg.value))
        result["value"] = toJson(struct)
    of "google.protobuf.Value":
        let value = newgoogle_protobuf_Value(cast[string](msg.value))
        result["value"] = toJson(value)
    of "google.protobuf.ListValue":
        let lst = newgoogle_protobuf_ListValue(cast[string](msg.value))
        result["value"] = toJson(lst)
    of "google.protobuf.Timestamp":
        let value = newgoogle_protobuf_Timestamp(cast[string](msg.value))
        result["value"] = toJson(value)
    of "google.protobuf.DoubleValue":
        let value = newgoogle_protobuf_DoubleValue(cast[string](msg.value))
        result["value"] = toJson(value)
    of "google.protobuf.FloatValue":
        let value = newgoogle_protobuf_FloatValue(cast[string](msg.value))
        result["value"] = toJson(value)
    of "google.protobuf.Int64Value":
        let value = newgoogle_protobuf_Int64Value(cast[string](msg.value))
        result["value"] = toJson(value)
    of "google.protobuf.UInt64Value":
        let value = newgoogle_protobuf_UInt64Value(cast[string](msg.value))
        result["value"] = toJson(value)
    of "google.protobuf.Int32Value":
        let value = newgoogle_protobuf_Int32Value(cast[string](msg.value))
        result["value"] = toJson(value)
    of "google.protobuf.UInt32Value":
        let value = newgoogle_protobuf_UInt32Value(cast[string](msg.value))
        result["value"] = toJson(value)
    of "google.protobuf.BoolValue":
        let value = newgoogle_protobuf_BoolValue(cast[string](msg.value))
        result["value"] = toJson(value)
    of "google.protobuf.StringValue":
        let value = newgoogle_protobuf_StringValue(cast[string](msg.value))
        result["value"] = toJson(value)
    of "google.protobuf.BytesValue":
        let value = newgoogle_protobuf_BytesValue(cast[string](msg.value))
        result["value"] = toJson(value)
    of "google.protobuf.Any":
        let value = newgoogle_protobuf_Any(cast[string](msg.value))
        result["value"] = toJson(value)
    else:
        if msg.typeUrl notin typeRegistry:
            raise newException(nimpb_json.ParseError,
                "unknown type url: " & msg.typeUrl)

        let
            procs = typeRegistry[msg.typeUrl]
            ss = newStringStream(cast[string](msg.value))
            submsg = procs.readImpl(ss)
            node = procs.toJsonImpl(submsg)

        for k, v in node:
            result[k] = v

proc parsegoogle_protobuf_Any*(node: JsonNode): google_protobuf_Any =
    ## Convert JSON into an Any.
    ##
    ## If the JSON represents a well known type, the conversion should succeed
    ## if the JSON is valid and represents a valid message.
    ##
    ## Otherwise, the type url of the embedded message needs to be registered
    ## in the type registry, so that this procs knows how to convert the JSON
    ## into a correct message.
    if node.kind != JObject:
        raise newException(nimpb_json.ParseError, "object expected")

    if "@type" notin node:
        raise newException(nimpb_json.ParseError, "@type not present")

    if node["@type"].kind != JString:
        raise newException(nimpb_json.ParseError,
            "@type is not a string (it's " & $node["@type"].kind & ")")

    let typeUrl = node["@type"].str
    let typeName = getTypenameFromTypeUrl(typeUrl)

    var
        subMessageData: string

    case typeName
    of "google.protobuf.Duration":
        let submsg = parsegoogle_protobuf_Duration(node["value"])
        subMessageData = serialize(submsg)
    of "google.protobuf.FieldMask":
        let submsg = parsegoogle_protobuf_FieldMask(node["value"])
        subMessageData = serialize(submsg)
    of "google.protobuf.Struct":
        let submsg = parsegoogle_protobuf_Struct(node["value"])
        subMessageData = serialize(submsg)
    of "google.protobuf.Value":
        let submsg = parsegoogle_protobuf_Value(node["value"])
        subMessageData = serialize(submsg)
    of "google.protobuf.ListValue":
        let submsg = parsegoogle_protobuf_ListValue(node["value"])
        subMessageData = serialize(submsg)
    of "google.protobuf.NullValue":
        # TODO: ?
        # let submsg = parsegoogle_protobuf_NullValue(node["value"])
        # subMessageData = serialize(submsg)
        discard
    of "google.protobuf.Timestamp":
        let submsg = parsegoogle_protobuf_Timestamp(node["value"])
        subMessageData = serialize(submsg)
    of "google.protobuf.DoubleValue":
        let submsg = parsegoogle_protobuf_DoubleValue(node["value"])
        subMessageData = serialize(submsg)
    of "google.protobuf.FloatValue":
        let submsg = parsegoogle_protobuf_FloatValue(node["value"])
        subMessageData = serialize(submsg)
    of "google.protobuf.Int64Value":
        let submsg = parsegoogle_protobuf_Int64Value(node["value"])
        subMessageData = serialize(submsg)
    of "google.protobuf.UInt64Value":
        let submsg = parsegoogle_protobuf_UInt64Value(node["value"])
        subMessageData = serialize(submsg)
    of "google.protobuf.Int32Value":
        let submsg = parsegoogle_protobuf_Int32Value(node["value"])
        subMessageData = serialize(submsg)
    of "google.protobuf.UInt32Value":
        let submsg = parsegoogle_protobuf_UInt32Value(node["value"])
        subMessageData = serialize(submsg)
    of "google.protobuf.BoolValue":
        let submsg = parsegoogle_protobuf_BoolValue(node["value"])
        subMessageData = serialize(submsg)
    of "google.protobuf.StringValue":
        let submsg = parsegoogle_protobuf_StringValue(node["value"])
        subMessageData = serialize(submsg)
    of "google.protobuf.BytesValue":
        let submsg = parsegoogle_protobuf_BytesValue(node["value"])
        subMessageData = serialize(submsg)
    of "google.protobuf.Any":
        let submsg = parsegoogle_protobuf_Any(node["value"])
        subMessageData = serialize(submsg)
    else:
        if typeUrl notin typeRegistry:
            raise newException(nimpb_json.ParseError,
                "unknown type url: " & typeUrl)

        let
            procs = typeRegistry[typeUrl]
            submsg = procs.fromJsonImpl(node)
            ss = newStringStream()

        procs.writeImpl(ss, submsg)

        subMessageData = ss.data

    result = newgoogle_protobuf_Any()
    result.typeUrl = typeUrl
    result.value = cast[seq[byte]](subMessageData)

declareJsonProcs(google_protobuf_Any)

# Register the Well Known Types to the type registry automatically.

template registerWkt(T: typedesc) =
    var procs = `T ProcsWithJson`()
    registerType("type.googleapis.com", fullyQualifiedName(T), procs)

registerWkt(google_protobuf_Duration)
registerWkt(google_protobuf_FieldMask)
registerWkt(google_protobuf_Struct)
registerWkt(google_protobuf_Value)
registerWkt(google_protobuf_ListValue)
registerWkt(google_protobuf_Timestamp)
registerWkt(google_protobuf_DoubleValue)
registerWkt(google_protobuf_FloatValue)
registerWkt(google_protobuf_Int64Value)
registerWkt(google_protobuf_UInt64Value)
registerWkt(google_protobuf_Int32Value)
registerWkt(google_protobuf_UInt32Value)
registerWkt(google_protobuf_BoolValue)
registerWkt(google_protobuf_StringValue)
registerWkt(google_protobuf_BytesValue)
registerWkt(google_protobuf_Any)
