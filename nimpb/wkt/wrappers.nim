import json

include wrappers_pb

proc toJson*(message: google_protobuf_DoubleValue): JsonNode =
    if hasValue(message):
        result = toJson(message.value)
    else:
        result = newJNull()

proc toJson*(message: google_protobuf_FloatValue): JsonNode =
    if hasValue(message):
        result = toJson(message.value)
    else:
        result = newJNull()

proc toJson*(message: google_protobuf_Int64Value): JsonNode =
    if hasValue(message):
        result = toJson(message.value)
    else:
        result = newJNull()

proc toJson*(message: google_protobuf_UInt64Value): JsonNode =
    if hasValue(message):
        result = toJson(message.value)
    else:
        result = newJNull()

proc toJson*(message: google_protobuf_Int32Value): JsonNode =
    if hasValue(message):
        result = %message.value
    else:
        result = newJNull()

proc toJson*(message: google_protobuf_UInt32Value): JsonNode =
    if hasValue(message):
        result = %message.value
    else:
        result = newJNull()

proc toJson*(message: google_protobuf_BoolValue): JsonNode =
    if hasValue(message):
        result = %message.value
    else:
        result = newJNull()

proc toJson*(message: google_protobuf_StringValue): JsonNode =
    if hasValue(message):
        result = %message.value
    else:
        result = newJNull()

proc toJson*(message: google_protobuf_BytesValue): JsonNode =
    if hasValue(message):
        result = %message.value
    else:
        result = newJNull()
