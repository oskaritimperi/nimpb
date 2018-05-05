## This module implements utilities for WKT modules.

template declareJsonProcs*(T: typedesc) =
    proc `T FromJsonImpl`(node: JsonNode): Message =
        `parse T`(node)

    proc `T ToJsonImpl`(msg: Message): JsonNode =
        toJson(T(msg))

    proc `T ProcsWithJson`*(): MessageProcs =
        result = `T Procs`()
        result.fromJsonImpl = `T FromJsonImpl`
        result.toJsonImpl = `T ToJsonImpl`
