import json
import strutils

include field_mask_pb

proc toJson*(message: google_protobuf_FieldMask): JsonNode =
    %join(message.paths, ",")
