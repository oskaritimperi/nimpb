import macros
import strutils

import types

type
    MessageDesc* = object
        name*: string
        fields*: seq[FieldDesc]

    FieldLabel* {.pure.} = enum
        Optional = 1
        Required
        Repeated

    FieldDesc* = object
        name*: string
        number*: int
        ftype*: FieldType
        label*: FieldLabel
        typeName*: string
        packed*: bool

proc toNimNode(ftype: FieldType): NimNode {.compileTime.} =
    case ftype
    of FieldType.Double: result = ident("float64")
    of FieldType.Float: result = ident("float32")
    of FieldType.Int64: result = ident("int64")
    of FieldType.UInt64: result = ident("uint64")
    of FieldType.Int32: result = ident("int32")
    of FieldType.Fixed64: result = ident("fixed64")
    of FieldType.Fixed32: result = ident("fixed32")
    of FieldType.Bool: result = ident("bool")
    of FieldType.String: result = ident("string")
    of FieldType.Group: result = ident("NOTIMPLEMENTED")
    of FieldType.Message: result = ident("TODO")
    of FieldType.Bytes: result = ident("bytes")
    of FieldType.UInt32: result = ident("uint32")
    of FieldType.Enum: result = ident("TODO")
    of FieldType.SFixed32: result = ident("sfixed32")
    of FieldType.SFixed64: result = ident("sfixed64")
    of FieldType.SInt32: result = ident("sint32")
    of FieldType.SInt64: result = ident("sint64")

proc findColonExpr(parent: NimNode, s: string): NimNode =
    for child in parent:
        if child.kind != nnkExprColonExpr:
            continue

        if $child[0] == s:
            return child

proc getMessageName(desc: NimNode): string =
    let node = findColonExpr(desc, "name")
    result = $node[1]

iterator fields(desc: NimNode): NimNode =
    let node = findColonExpr(desc, "fields")
    for field in node[1]:
        yield field

proc isRepeated(field: NimNode): bool =
    let node = findColonExpr(field, "label")
    let value = FieldLabel(node[1].intVal)
    result = value == FieldLabel.Repeated

proc isPacked(field: NimNode): bool =
    let node = findColonExpr(field, "packed")
    result = bool(node[1].intVal)

proc getFieldType(field: NimNode): FieldType =
    let node = findColonExpr(field, "ftype")
    result = FieldType(node[1].intVal)

proc getFullFieldType(field: NimNode): NimNode =
    let ftype = getFieldType(field)
    result = toNimNode(ftype)
    if isRepeated(field):
        result = nnkBracketExpr.newTree(ident("seq"), result)

proc getFieldName(field: NimNode): string =
    let node = findColonExpr(field, "name")
    result = $node[1]

proc getFieldNumber(field: NimNode): int =
    result = int(findColonExpr(field, "number")[1].intVal)

proc defaultValue(field: NimNode): NimNode =
    # TODO: check if there is a default value specified for the field

    if isRepeated(field):
        return nnkPrefix.newTree(newIdentNode("@"), nnkBracket.newTree())

    case getFieldType(field)
    of FieldType.Double: result = newLit(0.0'f64)
    of FieldType.Float: result = newLit(0.0'f32)
    of FieldType.Int64: result = newLit(0'i64)
    of FieldType.UInt64: result = newLit(0'u64)
    of FieldType.Int32: result = newLit(0'i32)
    of FieldType.Fixed64: result = newLit(0'u64)
    of FieldType.Fixed32: result = newLit(0'u32)
    of FieldType.Bool: result = newLit(false)
    of FieldType.String: result = newLit("")
    of FieldType.Group: result = newLit("NOTIMPLEMENTED")
    of FieldType.Message: result = newLit("TODO")
    of FieldType.Bytes: result = newCall(ident("bytes"), newLit(""))
    of FieldType.UInt32: result = newLit(0'u32)
    of FieldType.Enum: result = newLit("TODO")
    of FieldType.SFixed32: result = newCall(ident("sfixed32"), newLit(0))
    of FieldType.SFixed64: result = newCall(ident("sfixed64"), newLit(0))
    of FieldType.SInt32: result = newCall(ident("sint32"), newLit(0))
    of FieldType.SInt64: result = newCall(ident("sint64"), newLit(0))

proc wiretype(field: NimNode): WireType =
    result = wiretype(getFieldType(field))

proc fieldInitializer(objname: string, field: NimNode): NimNode =
    result = nnkAsgn.newTree(
        nnkDotExpr.newTree(
            newIdentNode(objname),
            newIdentNode(getFieldName(field))
        ),
        defaultValue(field)
    )

macro generateMessageType*(desc: typed): typed =
    let
        impl = getImpl(symbol(desc))
        typeSection = nnkTypeSection.newTree()
        typedef = nnkTypeDef.newTree()
        reclist = nnkRecList.newTree()

    let name = getMessageName(impl)

    let typedefRef = nnkTypeDef.newTree(postfix(newIdentNode(name), "*"), newEmptyNode(),
        nnkRefTy.newTree(newIdentNode(name & "Obj")))
    add(typeSection, typedefRef)

    add(typeSection, typedef)

    add(typedef, postfix(ident(name & "Obj"), "*"))
    add(typedef, newEmptyNode())
    add(typedef, nnkObjectTy.newTree(newEmptyNode(), newEmptyNode(), reclist))

    for field in fields(impl):
        let ftype = getFullFieldType(field)
        let name = ident(getFieldName(field))
        add(reclist, newIdentDefs(name, ftype))

    add(reclist, nnkIdentDefs.newTree(
        ident("hasField"), ident("IntSet"), newEmptyNode()))

    result = newStmtList()
    add(result, typeSection)

    when defined(debug):
        hint(repr(result))

proc generateNewMessageProc(desc: NimNode): NimNode =
    let body = newStmtList(
        newCall(ident("new"), ident("result"))
    )

    for field in fields(desc):
        add(body, fieldInitializer("result", field))

    add(body, newAssignment(newDotExpr(ident("result"), ident("hasField")),
        newCall(ident("initIntSet"))))

    result = newProc(postfix(ident("new" & getMessageName(desc)), "*"),
        @[ident(getMessageName(desc))],
        body)

proc generateClearFieldProc(desc, field: NimNode): NimNode =
    let body = nnkStmtList.newTree()

    let messageName = getMessageName(desc)
    let fieldName = getFieldName(field)

    add(body, fieldInitializer("message", field))

    add(body, nnkCall.newTree(
        ident("excl"),
        nnkDotExpr.newTree(
            ident("message"),
            ident("hasField")
        ),
        newLit(getFieldNumber(field))
    ))

    result = newProc(postfix(ident("clear" & capitalizeAscii(fieldName)), "*"),
        @[newEmptyNode(), newIdentDefs(ident("message"), ident(messageName))],
        body)

proc generateHasFieldProc(desc, field: NimNode): NimNode =
    let body = nnkCall.newTree(
        ident("contains"),
        newDotExpr(ident("message"), ident("hasField")),
        newLit(getFieldNumber(field))
    )

    let messageName = getMessageName(desc)
    let fieldName = getFieldName(field)

    result = newProc(postfix(ident("has" & capitalizeAscii(fieldName)), "*"),
        @[ident("bool"), newIdentDefs(ident("message"), ident(messageName))],
        body)

proc generateSetFieldProc(desc, field: NimNode): NimNode =
    # let body = nnkStmtList.newTree(nnkDiscardStmt.newTree(newEmptyNode()))

    let body = newStmtList()

    let messageName = getMessageName(desc)
    let fieldName = getFieldName(field)

    add(body, newAssignment(newDotExpr(ident("message"), ident(fieldName)), ident("value")))

    add(body, newCall("incl", newDotExpr(ident("message"), ident("hasField")),
        newLit(getFieldNumber(field))))

    let ftype = getFullFieldType(field)

    result = newProc(postfix(ident("set" & capitalizeAscii(fieldName)), "*"),
        @[newEmptyNode(), newIdentDefs(ident("message"),
            ident(messageName)),
            newIdentDefs(ident("value"), ftype)],
        body)

proc generateAddToFieldProc(desc, field: NimNode): NimNode =
    let body = newStmtList()

    let messageName = getMessageName(desc)
    let fieldName = getFieldName(field)

    add(body, newCall(
        ident("add"),
        newDotExpr(ident("message"), ident(fieldName)),
        ident("value")
    ))

    add(body, newCall("incl", newDotExpr(ident("message"), ident("hasField")),
        newLit(getFieldNumber(field))))

    let ftype = toNimNode(getFieldType(field))

    result = newProc(postfix(ident("add" & capitalizeAscii(fieldName)), "*"),
        @[newEmptyNode(), newIdentDefs(ident("message"),
            ident(messageName)),
            newIdentDefs(ident("value"), ftype)],
        body)

proc ident(wt: WireType): NimNode =
    result = newDotExpr(ident("WireType"), ident($wt))

proc genWriteField(field: NimNode): NimNode =
    result = newStmtList()

    let
        number = getFieldNumber(field)
        writer = ident("write" & $getFieldType(field))
        fname = newDotExpr(ident("message"), ident(getFieldName(field)))
        wiretype = ident(wiretype(field))

    if not isRepeated(field):
        result.add quote do:
            writeTag(stream, `number`, `wiretype`)
            `writer`(stream, `fname`)
    else:
        if isPacked(field):
            result.add quote do:
                writeTag(stream, `number`, WireType.LengthDelimited)
                writeVarInt(stream, packedFieldSize(`fname`, `wiretype`))
                for value in `fname`:
                    `writer`(stream, value)
        else:
            result.add quote do:
                for value in `fname`:
                    writeTag(stream, `number`, `wiretype`)
                    `writer`(stream, value)

proc generateWriteMessageProc(desc: NimNode): NimNode =
    let body = newStmtList()

    let name = getMessageName(desc)

    for field in fields(desc):
        add(body, nnkIfStmt.newTree(
            nnkElifBranch.newTree(
                newCall(ident("has" & capitalizeAscii(getFieldName(field))),
                    ident("message")),
                genWriteField(field)
            )
        ))

    result = newProc(postfix(ident("write" & name), "*"),
        @[newEmptyNode(),
          newIdentDefs(ident("stream"), ident("ProtobufStream")),
          newIdentDefs(ident("message"), ident(name))],
        body)

proc generateReadMessageProc(desc: NimNode): NimNode =
    let name = getMessageName(desc)

    let resultId = ident("result")

    let body = newStmtList(
        newCall(ident("new"), resultId)
    )

    let tagid = ident("tag")
    let wiretypeId = ident("wiretype")

    body.add quote do:
        while not atEnd(stream):
            let
                `tagId` = readTag(stream)
                `wiretypeId` = getTagWireType(`tagId`)
            case getTagFieldNumber(`tagId`)

    let caseNode = body[^1][1][1]

    # TODO: check wiretypes and fail if it doesn't match
    for field in fields(desc):
        let number = getFieldNumber(field)
        if isRepeated(field):
            let adder = ident("add" & capitalizeAscii(getFieldName(field)))
            let reader = ident("read" & $getFieldType(field))
            if isNumeric(getFieldType(field)):
                add(caseNode, nnkOfBranch.newTree(newLit(number), quote do:
                    if `wiretypeId` == WireType.LengthDelimited:
                        # TODO: do this only if it makes sense, i.e. with primitives?
                        let
                            size = readVarint(stream)
                            start = getPosition(stream).uint64
                        var consumed = 0'u64
                        while consumed < size:
                            `adder`(`resultId`, `reader`(stream))
                            consumed = getPosition(stream).uint64 - start
                        if consumed != size:
                            raise newException(Exception, "packed field size mismatch")
                    else:
                        `adder`(`resultId`, `reader`(stream))
                ))
            else:
                add(caseNode, nnkOfBranch.newTree(newLit(number), quote do:
                    `adder`(`resultId`, `reader`(stream))
                ))
        else:
            let setter = ident("set" & capitalizeAscii(getFieldName(field)))
            let reader = ident("read" & $getFieldType(field))
            add(caseNode, nnkOfBranch.newTree(newLit(number), quote do:
                `setter`(`resultId`, `reader`(stream))
            ))

    # TODO: generate code to skip unknown fields
    add(caseNode, nnkElse.newTree(quote do:
        raise newException(Exception, "unknown field")
    ))

    result = newProc(postfix(ident("read" & name), "*"),
        @[ident(name), newIdentDefs(ident("stream"), ident("ProtobufStream"))],
        body)

macro generateMessageProcs*(x: typed): typed =
    let
        desc = getImpl(symbol(x))

    result = newStmtList(
        generateNewMessageProc(desc),
    )

    for field in fields(desc):
        add(result, generateClearFieldProc(desc, field))
        add(result, generateHasFieldProc(desc, field))
        add(result, generateSetFieldProc(desc, field))

        if isRepeated(field):
            add(result, generateAddToFieldProc(desc, field))

    add(result, generateWriteMessageProc(desc))
    add(result, generateReadMessageProc(desc))

    when defined(debug):
        hint(repr(result))
