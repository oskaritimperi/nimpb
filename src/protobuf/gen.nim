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

proc isMessage(field: NimNode): bool =
    result = getFieldType(field) == FieldType.Message

proc getFieldTypeName(field: NimNode): string =
    let node = findColonExpr(field, "typeName")
    result = $node[1]

proc getFieldTypeAsString(field: NimNode): string =
    if isMessage(field):
        result = getFieldTypeName(field)
    else:
        case getFieldType(field)
        of FieldType.Double: result = "float64"
        of FieldType.Float: result = "float32"
        of FieldType.Int64: result = "int64"
        of FieldType.UInt64: result = "uint64"
        of FieldType.Int32: result = "int32"
        of FieldType.Fixed64: result = "fixed64"
        of FieldType.Fixed32: result = "fixed32"
        of FieldType.Bool: result = "bool"
        of FieldType.String: result = "string"
        of FieldType.Bytes: result = "bytes"
        of FieldType.UInt32: result = "uint32"
        of FieldType.SFixed32: result = "sfixed32"
        of FieldType.SFixed64: result = "sfixed64"
        of FieldType.SInt32: result = "sint32"
        of FieldType.SInt64: result = "sint64"
        else: result = "AYBABTU"

proc getFullFieldType(field: NimNode): NimNode =
    result = ident(getFieldTypeAsString(field))
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
    of FieldType.Message: result = newCall(ident("new" & getFieldTypeAsString(field)))
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

proc fieldProcName(prefix: string, field: NimNode): string =
    result = prefix & capitalizeAscii(getFieldName(field))

proc fieldProcIdent(prefix: string, field: NimNode): NimNode =
    result = postfix(ident(fieldProcName(prefix, field)), "*")

proc generateClearFieldProc(desc, field: NimNode): NimNode =
    let
        messageId = ident("message")
        fname = newDotExpr(messageId, ident(getFieldName(field)))
        defvalue = defaultValue(field)
        hasField = newDotExpr(messageId, ident("hasField"))
        number = getFieldNumber(field)
        procName = fieldProcIdent("clear", field)
        mtype = ident(getMessageName(desc))

    result = quote do:
        proc `procName`(`messageId`: `mtype`) =
            `fname` = `defvalue`
            excl(`hasfield`, `number`)

proc generateHasFieldProc(desc, field: NimNode): NimNode =
    let
        messageId = ident("message")
        hasField = newDotExpr(messageId, ident("hasField"))
        number = getFieldNumber(field)
        mtype = ident(getMessageName(desc))
        procName = fieldProcIdent("has", field)

    result = quote do:
        proc `procName`(`messageId`: `mtype`): bool =
            contains(`hasfield`, `number`)

proc generateSetFieldProc(desc, field: NimNode): NimNode =
    let
        messageId = ident("message")
        hasField = newDotExpr(messageId, ident("hasField"))
        number = getFieldNumber(field)
        valueId = ident("value")
        fname = newDotExpr(messageId, ident(getFieldName(field)))
        procName = fieldProcIdent("set", field)
        mtype = ident(getMessageName(desc))
        ftype = getFullFieldType(field)

    result = quote do:
        proc `procName`(`messageId`: `mtype`, `valueId`: `ftype`) =
            `fname` = `valueId`
            incl(`hasfield`, `number`)

proc generateAddToFieldProc(desc, field: NimNode): NimNode =
    let
        procName = fieldProcIdent("add", field)
        messageId = ident("message")
        mtype = ident(getMessageName(desc))
        valueId = ident("value")
        ftype = ident(getFieldTypeAsString(field))
        hasField = newDotExpr(messageId, ident("hasField"))
        number = getFieldNumber(field)
        fname = newDotExpr(messageId, ident(getFieldName(field)))

    result = quote do:
        proc `procName`(`messageId`: `mtype`, `valueId`: `ftype`) =
            add(`fname`, `valueId`)
            incl(`hasfield`, `number`)

proc ident(wt: WireType): NimNode =
    result = newDotExpr(ident("WireType"), ident($wt))

proc genWriteField(field: NimNode): NimNode =
    result = newStmtList()

    let
        number = getFieldNumber(field)
        writer = ident("write" & getFieldTypeAsString(field))
        fname = newDotExpr(ident("message"), ident(getFieldName(field)))
        wiretype = ident(wiretype(field))

    if not isRepeated(field):
        result.add quote do:
            writeTag(stream, `number`, `wiretype`)
            `writer`(stream, `fname`)
        if isMessage(field):
            insert(result[^1], 1, newCall(ident("writeVarint"), ident("stream"),
                newCall(ident("sizeOf" & getFieldTypeAsString(field)), fname)))
    else:
        if isPacked(field):
            result.add quote do:
                writeTag(stream, `number`, WireType.LengthDelimited)
                writeVarInt(stream, packedFieldSize(`fname`, `wiretype`))
                for value in `fname`:
                    `writer`(stream, value)
        else:
            let valueId = ident("value")
            result.add quote do:
                for `valueId` in `fname`:
                    writeTag(stream, `number`, `wiretype`)
                    `writer`(stream, `valueId`)
            if isMessage(field):
                insert(result[^1][^1], 1, newCall(ident("writeVarint"), ident("stream"),
                    newCall(ident("sizeOf" & getFieldTypeAsString(field)), valueId)))

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
        newAssignment(resultId, newCall(ident("new" & getMessageName(desc))))
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
            let reader = ident("read" & getFieldTypeAsString(field))
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
                if isMessage(field):
                    add(caseNode, nnkOfBranch.newTree(newLit(number), quote do:
                        let size = readVarint(stream)
                        let data = readStr(stream, int(size))
                        let stream2 = newProtobufStream(newStringStream(data))
                        `adder`(`resultId`, `reader`(stream2))
                    ))
                else:
                    add(caseNode, nnkOfBranch.newTree(newLit(number), quote do:
                        `adder`(`resultId`, `reader`(stream))
                    ))
        else:
            let setter = ident("set" & capitalizeAscii(getFieldName(field)))
            let reader = ident("read" & getFieldTypeAsString(field))
            if isMessage(field):
                add(caseNode, nnkOfBranch.newTree(newLit(number), quote do:
                    let size = readVarint(stream)
                    let data = readStr(stream, int(size))
                    let stream2 = newProtobufStream(newStringStream(data))
                    `setter`(`resultId`, `reader`(stream2))
                ))
            else:
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

proc generateSizeOfMessageProc(desc: NimNode): NimNode =
    let
        name = getMessageName(desc)
        body = newStmtList()
        messageId = ident("message")
        resultId = ident("result")

    for field in fields(desc):
        let
            hasproc = ident("has" & capitalizeAscii(getFieldName(field)))
            sizeofproc = ident("sizeOf" & getFieldTypeAsString(field))
            fname = newDotExpr(messageId, ident(getFieldName(field)))
            number = getFieldNumber(field)
            wiretype = ident(wiretype(field))

        # TODO: packed
        if isRepeated(field):
            body.add quote do:
                if `hasproc`(`messageId`):
                    for value in `fname`:
                        let
                            sizeOfField = `sizeofproc`(value)
                            tagSize = sizeOfUint32(uint32(makeTag(`number`, `wiretype`)))
                        `resultId` = `resultId` +
                            sizeOfField +
                            sizeOfUint64(sizeOfField) +
                            tagSize
        else:
            if isMessage(field):
                body.add quote do:
                    if `hasproc`(`messageId`):
                        let
                            sizeOfField = `sizeofproc`(`fname`)
                            tagSize = sizeOfUint32(uint32(makeTag(`number`, `wiretype`)))
                        `resultId` = `resultId` + sizeOfField + tagSize +
                            sizeOfUint64(sizeOfField)
            else:
                body.add quote do:
                    if `hasproc`(`messageId`):
                        let
                            sizeOfField = `sizeofproc`(`fname`)
                            tagSize = sizeOfUint32(uint32(makeTag(`number`, `wiretype`)))
                        `resultId` = `resultId` + sizeOfField + tagSize

    result = newProc(postfix(ident("sizeOf" & name), "*"),
        @[ident("uint64"), newIdentDefs(messageId, ident(name))],
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
    add(result, generateSizeOfMessageProc(desc))

    when defined(debug):
        hint(repr(result))
