import json

import duration
import field_mask
import struct
import timestamp

include any_pb

proc toJson*(message: google_protobuf_Any): JsonNode =
    case message.typeUrl
    of "type.googleapis.com/google.protobuf.Duration":
        let duration = newGoogleProtobufDuration(message.value)
        result = newJObject()
        result["@type"] = %message.typeUrl
        result["value"] = toJson(duration)
    of "type.googleapis.com/google.protobuf.Empty":
        result = newJObject()
        result["@type"] = %message.typeUrl
        result["value"] = newJObject()
    of "type.googleapis.com/google.protobuf.FieldMask":
        let mask = newGoogleProtobufFieldMask(message.value)
        result = newJObject()
        result["@type"] = %message.typeUrl
        result["value"] = toJson(mask)
    of "type.googleapis.com/google.protobuf.Struct":
        let struct = newGoogleProtobufStruct(message.value)
        result = newJObject()
        result["@type"] = %message.typeUrl
        result["value"] = toJson(struct)
    of "type.googleapis.com/google.protobuf.Value":
        let value = newGoogleProtobufValue(message.value)
        result = newJObject()
        result["@type"] = %message.typeUrl
        result["value"] = toJson(value)
    of "type.googleapis.com/google.protobuf.ListValue":
        let lst = newGoogleProtobufListValue(message.value)
        result = newJObject()
        result["@type"] = %message.typeUrl
        result["value"] = toJson(lst)
    of "type.googleapis.com/google.protobuf.Timestamp":
        let value = newGoogleProtobufTimestamp(message.value)
        result = newJObject()
        result["@type"] = %message.typeUrl
        result["value"] = toJson(value)
    else:
        result = newJObject()
        result["typeUrl"] = %message.typeUrl
        result["value"] = %message.value
