import algorithm
import os
import pegs
import sequtils
import sets
import strformat
import strutils
import tables

import descriptor_pb
import plugin_pb

import protobuf/protobuf
import protobuf/gen

type
    Names = distinct seq[string]

    Enum = ref object
        names: Names
        values: seq[tuple[name: string, number: int]]

    Field = ref object
        number: int
        name: string
        label: FieldDescriptorProto_Label
        ftype: FieldDescriptorProto_Type
        typeName: string
        packed: bool
        oneof: Oneof
        mapEntry: Message

    Message = ref object
        names: Names
        fields: seq[Field]
        oneofs: seq[Oneof]
        mapEntry: bool

    Oneof = ref object
        name: string
        fields: seq[Field]

    ProcessedFile = ref object
        name: string
        data: string

    ProtoFile = ref object
        fdesc: FileDescriptorProto
        enums: seq[Enum]
        messages: seq[Message]
        syntax: Syntax

    Syntax {.pure.} = enum
        Proto2
        Proto3

when defined(debug):
    proc log(msg: string) =
        stderr.write(msg)
        stderr.write("\n")
else:
    proc log(msg: string) = discard

proc initNamesFromTypeName(typename: string): Names =
    if typename[0] != '.':
        raise newException(Exception, "relative names not supported")
    let parts = split(typename[1..^1], ".")
    result = Names(parts)

proc `$`(names: Names): string =
    let n = seq[string](names)
    result = join(n, "_")

proc add(names: var Names, s: string) =
    add(seq[string](names), s)

proc `&`(names: Names, s: string): Names =
    result = names
    add(result, s)

proc isRepeated(field: Field): bool =
    result = field.label == FieldDescriptorProtoLabel.LabelRepeated

proc isMessage(field: Field): bool =
    result = field.ftype == FieldDescriptorProtoType.TypeMessage

proc isEnum(field: Field): bool =
    result = field.ftype == FieldDescriptorProtoType.TypeEnum

proc isNumeric(field: Field): bool =
    case field.ftype
    of FieldDescriptorProtoType.TypeDouble, FieldDescriptorProtoType.TypeFloat,
       FieldDescriptorProtoType.TypeInt64, FieldDescriptorProtoType.TypeUInt64,
       FieldDescriptorProtoType.TypeInt32, FieldDescriptorProtoType.TypeFixed64,
       FieldDescriptorProtoType.TypeFixed32, FieldDescriptorProtoType.TypeBool,
       FieldDescriptorProtoType.TypeUInt32, FieldDescriptorProtoType.TypeEnum,
       FieldDescriptorProtoType.TypeSFixed32, FieldDescriptorProtoType.TypeSFixed64,
       FieldDescriptorProtoType.TypeSInt32, FieldDescriptorProtoType.TypeSInt64:
       result = true
    else: discard

proc isMapEntry(message: Message): bool =
    result = message.mapEntry

proc isMapEntry(field: Field): bool =
    result = field.mapEntry != nil

proc nimTypeName(field: Field): string =
    case field.ftype
    of FieldDescriptorProtoType.TypeDouble: result = "float64"
    of FieldDescriptorProtoType.TypeFloat: result = "float32"
    of FieldDescriptorProtoType.TypeInt64: result = "int64"
    of FieldDescriptorProtoType.TypeUInt64: result = "uint64"
    of FieldDescriptorProtoType.TypeInt32: result = "int32"
    of FieldDescriptorProtoType.TypeFixed64: result = "uint64"
    of FieldDescriptorProtoType.TypeFixed32: result = "uint32"
    of FieldDescriptorProtoType.TypeBool: result = "bool"
    of FieldDescriptorProtoType.TypeString: result = "string"
    of FieldDescriptorProtoType.TypeGroup: result = ""
    of FieldDescriptorProtoType.TypeMessage: result = field.typeName
    of FieldDescriptorProtoType.TypeBytes: result = "bytes"
    of FieldDescriptorProtoType.TypeUInt32: result = "uint32"
    of FieldDescriptorProtoType.TypeEnum: result = field.typeName
    of FieldDescriptorProtoType.TypeSFixed32: result = "int32"
    of FieldDescriptorProtoType.TypeSFixed64: result = "int64"
    of FieldDescriptorProtoType.TypeSInt32: result = "int32"
    of FieldDescriptorProtoType.TypeSInt64: result = "int64"

proc mapKeyType(field: Field): string =
    for f in field.mapEntry.fields:
        if f.name == "key":
            return f.nimTypeName

proc mapValueType(field: Field): string =
    for f in field.mapEntry.fields:
        if f.name == "value":
            return f.nimTypeName

proc `$`(ft: FieldDescriptorProtoType): string =
    case ft
    of FieldDescriptorProtoType.TypeDouble: result = "Double"
    of FieldDescriptorProtoType.TypeFloat: result = "Float"
    of FieldDescriptorProtoType.TypeInt64: result = "Int64"
    of FieldDescriptorProtoType.TypeUInt64: result = "UInt64"
    of FieldDescriptorProtoType.TypeInt32: result = "Int32"
    of FieldDescriptorProtoType.TypeFixed64: result = "Fixed64"
    of FieldDescriptorProtoType.TypeFixed32: result = "Fixed32"
    of FieldDescriptorProtoType.TypeBool: result = "Bool"
    of FieldDescriptorProtoType.TypeString: result = "String"
    of FieldDescriptorProtoType.TypeGroup: result = "Group"
    of FieldDescriptorProtoType.TypeMessage: result = "Message"
    of FieldDescriptorProtoType.TypeBytes: result = "Bytes"
    of FieldDescriptorProtoType.TypeUInt32: result = "UInt32"
    of FieldDescriptorProtoType.TypeEnum: result = "Enum"
    of FieldDescriptorProtoType.TypeSFixed32: result = "SFixed32"
    of FieldDescriptorProtoType.TypeSFixed64: result = "SFixed64"
    of FieldDescriptorProtoType.TypeSInt32: result = "SInt32"
    of FieldDescriptorProtoType.TypeSInt64: result = "SInt64"

proc defaultValue(field: Field): string =
    if isMapEntry(field):
        return &"newTable[{field.mapKeyType}, {field.mapValueType}]()"
    elif isRepeated(field):
        return "@[]"

    case field.ftype
    of FieldDescriptorProtoType.TypeDouble: result = "0"
    of FieldDescriptorProtoType.TypeFloat: result = "0"
    of FieldDescriptorProtoType.TypeInt64: result = "0"
    of FieldDescriptorProtoType.TypeUInt64: result = "0"
    of FieldDescriptorProtoType.TypeInt32: result = "0"
    of FieldDescriptorProtoType.TypeFixed64: result = "0"
    of FieldDescriptorProtoType.TypeFixed32: result = "0"
    of FieldDescriptorProtoType.TypeBool: result = "false"
    of FieldDescriptorProtoType.TypeString: result = "\"\""
    of FieldDescriptorProtoType.TypeGroup: result = ""
    of FieldDescriptorProtoType.TypeMessage: result = "nil"
    of FieldDescriptorProtoType.TypeBytes: result = "bytes(\"\")"
    of FieldDescriptorProtoType.TypeUInt32: result = "0"
    of FieldDescriptorProtoType.TypeEnum: result = &"{field.typeName}(0)"
    of FieldDescriptorProtoType.TypeSFixed32: result = "0"
    of FieldDescriptorProtoType.TypeSFixed64: result = "0"
    of FieldDescriptorProtoType.TypeSInt32: result = "0"
    of FieldDescriptorProtoType.TypeSInt64: result = "0"

proc wiretypeStr(field: Field): string =
    result = "WireType."
    case field.ftype
    of FieldDescriptorProtoType.TypeDouble: result &= "Fixed64"
    of FieldDescriptorProtoType.TypeFloat: result &= "Fixed32"
    of FieldDescriptorProtoType.TypeInt64: result &= "Varint"
    of FieldDescriptorProtoType.TypeUInt64: result &= "Varint"
    of FieldDescriptorProtoType.TypeInt32: result &= "Varint"
    of FieldDescriptorProtoType.TypeFixed64: result &= "Fixed64"
    of FieldDescriptorProtoType.TypeFixed32: result &= "Fixed32"
    of FieldDescriptorProtoType.TypeBool: result &= "Varint"
    of FieldDescriptorProtoType.TypeString: result &= "LengthDelimited"
    of FieldDescriptorProtoType.TypeGroup: result &= ""
    of FieldDescriptorProtoType.TypeMessage: result &= "LengthDelimited"
    of FieldDescriptorProtoType.TypeBytes: result &= "LengthDelimited"
    of FieldDescriptorProtoType.TypeUInt32: result &= "Varint"
    of FieldDescriptorProtoType.TypeEnum: result &= &"Varint"
    of FieldDescriptorProtoType.TypeSFixed32: result &= "Fixed32"
    of FieldDescriptorProtoType.TypeSFixed64: result &= "Fixed64"
    of FieldDescriptorProtoType.TypeSInt32: result &= "Varint"
    of FieldDescriptorProtoType.TypeSInt64: result &= "Varint"

proc fieldTypeStr(field: Field): string =
    result = "FieldType." & $field.ftype

proc isKeyword(s: string): bool =
    case s
    of "addr", "and", "as", "asm", "bind", "block", "break", "case", "cast",
       "concept", "const", "continue", "converter", "defer", "discard",
       "distinct", "div", "do", "elif", "else", "end", "enum", "except",
       "export", "finally", "for", "from", "func", "if", "import", "in",
       "include", "interface", "is", "isnot", "iterator", "let", "macro",
       "method", "mixin", "mod", "nil", "not", "notin", "object", "of", "or",
       "out", "proc", "ptr", "raise", "ref", "return", "shl", "shr", "static",
       "template", "try", "tuple", "type", "using", "var", "when", "while",
       "xor", "yield":
        result = true
    else:
        result = false

proc newField(file: ProtoFile, message: Message, desc: FieldDescriptorProto): Field =
    new(result)

    result.name = desc.name
    result.number = desc.number
    result.label = desc.label
    result.ftype = desc.type
    result.typeName = ""
    result.packed = false
    result.mapEntry = nil

    # Identifiers cannot start/end with underscore
    removePrefix(result.name, '_')
    removeSuffix(result.name, '_')

    # Consecutive underscores are not allowed
    result.name = replace(result.name, peg"'_' '_'+", "_")

    if isKeyword(result.name):
        result.name = "f" & result.name

    if isRepeated(result) and isNumeric(result):
        if hasOptions(desc):
            if hasPacked(desc.options):
                result.packed = desc.options.packed
            else:
                result.packed =
                    if file.syntax == Syntax.Proto2:
                        false
                    else:
                        true
        else:
            result.packed =
                if file.syntax == Syntax.Proto2:
                    false
                else:
                    true

    if hasOneof_index(desc):
        result.oneof = message.oneofs[desc.oneof_index]
        add(result.oneof.fields, result)

    if isMessage(result) or isEnum(result):
        result.typeName = $initNamesFromTypeName(desc.type_name)
    else:
        result.typeName = $result.ftype

    log(&"newField {result.name} {$result.ftype} {result.typeName} PACKED={result.packed} SYNTAX={file.syntax}")

proc newOneof(name: string): Oneof =
    new(result)
    result.fields = @[]
    result.name = name

proc newMessage(file: ProtoFile, names: Names, desc: DescriptorProto): Message =
    new(result)

    result.names = names
    result.fields = @[]
    result.oneofs = @[]
    result.mapEntry = false

    if hasMapEntry(desc.options):
        result.mapEntry = desc.options.mapEntry

    log(&"newMessage {$result.names}")

    for oneof in desc.oneof_decl:
        add(result.oneofs, newOneof(oneof.name))

    for field in desc.field:
        add(result.fields, newField(file, result, field))

proc fixMapEntry(file: ProtoFile, message: Message): bool =
    for field in message.fields:
        for msg in file.messages:
            if $msg.names == field.typeName:
                if msg.mapEntry:
                    log(&"fixing map {field.name} {msg.names}")
                    field.mapEntry = msg
                    result = true

proc newEnum(names: Names, desc: EnumDescriptorProto): Enum =
    new(result)

    result.names = names & desc.name
    result.values = @[]

    log(&"newEnum {$result.names}")

    for value in desc.value:
        add(result.values, (value.name, int(value.number)))

    type EnumValue = tuple[name: string, number: int]

    sort(result.values, proc (x, y: EnumValue): int =
        system.cmp(x.number, y.number)
    )

iterator messages(desc: DescriptorProto, names: Names): tuple[names: Names, desc: DescriptorProto] =
    var stack: seq[tuple[names: Names, desc: DescriptorProto]] = @[]

    for nested in desc.nested_type:
        add(stack, (names, nested))

    while len(stack) > 0:
        let (names, submsg) = pop(stack)

        let subnames = names & submsg.name
        yield (subnames, submsg)

        for desc in submsg.nested_type:
            add(stack, (subnames, desc))

iterator messages(fdesc: FileDescriptorProto, names: Names): tuple[names: Names, desc: DescriptorProto] =
    for desc in fdesc.message_type:
        let subnames = names & desc.name
        yield (subnames, desc)

        for x in messages(desc, subnames):
            yield x

proc quoteReserved(name: string): string =
    case name
    of "type": result = &"`{name}`"
    else: result = name

proc accessor(field: Field): string =
    if field.oneof != nil:
        result = &"{field.oneof.name}.{quoteReserved(field.name)}"
    else:
        result = quoteReserved(field.name)

proc dependencies(field: Field): seq[string] =
    result = @[]

    if isMessage(field) or isEnum(field):
        add(result, field.typeName)

proc dependencies(message: Message): seq[string] =
    result = @[]

    for field in message.fields:
        add(result, dependencies(field))

proc toposort(graph: TableRef[string, HashSet[string]]): seq[string] =
    type State = enum Unknown, Gray, Black

    var
        enter = toSeq(keys(graph))
        state = newTable[string, State]()
        order: seq[string] = @[]

    proc dfs(node: string) =
        state[node] = Gray
        if node in graph:
            for k in graph[node]:
                let sk =
                    if k in state:
                        state[k]
                    else:
                        Unknown

                if sk == Gray:
                    # cycle
                    continue
                elif sk == Black:
                    continue

                let idx = find(enter, k)
                if idx != -1:
                    delete(enter, idx)

                dfs(k)
        insert(order, node, 0)
        state[node] = Black

    while len(enter) > 0:
        dfs(pop(enter))

    result = order

iterator sortDependencies(messages: seq[Message]): Message =
    let
        deps = newTable[string, HashSet[string]]()
        byname = newTable[string, Message]()

    for message in messages:
        deps[$message.names] = toSet(dependencies(message))
        byname[$message.names] = message

    let order = reversed(toposort(deps))

    for name in order:
        if name in byname:
            yield byname[name]

proc parseFile(name: string, fdesc: FileDescriptorProto): ProtoFile =
    log(&"parsing {name}")

    new(result)

    result.fdesc = fdesc
    result.messages = @[]
    result.enums = @[]

    if hasSyntax(fdesc):
        if fdesc.syntax == "proto2":
            result.syntax = Syntax.Proto2
        elif fdesc.syntax == "proto3":
            result.syntax = Syntax.Proto3
        else:
            raise newException(Exception, "unrecognized syntax: " & fdesc.syntax)
    else:
        result.syntax = Syntax.Proto2

    let basename =
        if hasPackage(fdesc):
            Names(split(fdesc.package, "."))
        else:
            Names(@[])

    for e in fdesc.enum_type:
        add(result.enums, newEnum(basename, e))

    for name, message in messages(fdesc, basename):
        add(result.messages, newMessage(result, name, message))

        for e in message.enum_type:
            add(result.enums, newEnum(name, e))

proc addLine(s: var string, line: string) =
    if not isNilOrWhitespace(line):
        s &= line
    s &= "\n"

iterator genType(e: Enum): string =
    yield &"{e.names}* {{.pure.}} = enum"
    for item in e.values:
        let (name, number) = item
        yield indent(&"{name} = {number}", 4)

proc fullType(field: Field): string =
    if isMapEntry(field):
        result = &"TableRef[{field.mapKeyType}, {field.mapValueType}]"
    else:
        result = field.nimTypeName
        if isRepeated(field):
            result = &"seq[{result}]"

proc mapKeyField(message: Message): Field =
    for field in message.fields:
        if field.name == "key":
            return field

proc mapValueField(message: Message): Field =
    for field in message.fields:
        if field.name == "value":
            return field

iterator genType(message: Message): string =
    yield &"{message.names}* = ref {message.names}Obj"
    yield &"{message.names}Obj* = object of RootObj"
    yield indent(&"hasField: IntSet", 4)

    for field in message.fields:
        if isMapEntry(field):
            yield indent(&"{field.name}: TableRef[{mapKeyType(field)}, {mapValueType(field)}]", 4)
        elif field.oneof == nil:
            yield indent(&"{quoteReserved(field.name)}: {field.fullType}", 4)

    for oneof in message.oneofs:
        yield indent(&"{oneof.name}: {message.names}_{oneof.name}_OneOf", 4)

    for oneof in message.oneofs:
        yield ""
        yield &"{message.names}_{oneof.name}_OneOf* {{.union.}} = object"
        for field in oneof.fields:
            yield indent(&"{quoteReserved(field.name)}: {field.fullType}", 4)

iterator genProcs(e: Enum): string =
    yield &"proc read{e.names}*(stream: ProtobufStream): {e.names} ="
    yield indent(&"{e.names}(readUInt32(stream))", 4)
    yield ""
    yield &"proc write{e.names}*(stream: ProtobufStream, value: {e.names}) ="
    yield indent(&"writeUInt32(stream, uint32(value))", 4)
    yield ""
    yield &"proc sizeOf{e.names}*(value: {e.names}): uint64 ="
    yield indent(&"sizeOfUInt32(uint32(value))", 4)

iterator genNewMessageProc(msg: Message): string =
    yield &"proc new{msg.names}*(): {msg.names} ="
    yield indent("new(result)", 4)
    yield indent("result.hasField = initIntSet()", 4)
    for field in msg.fields:
        yield indent(&"result.{field.accessor} = {defaultValue(field)}", 4)
    yield ""

iterator oneofSiblings(field: Field): Field =
    if field.oneof != nil:
        for sibling in field.oneof.fields:
            if sibling == field:
                continue
            yield sibling

iterator genClearFieldProc(msg: Message, field: Field): string =
    yield &"proc clear{field.name}*(message: {msg.names}) ="
    yield indent(&"message.{field.accessor} = {defaultValue(field)}", 4)
    yield indent(&"excl(message.hasField, {field.number})", 4)
    for sibling in oneofSiblings(field):
        yield indent(&"excl(message.hasField, {sibling.number})", 4)
    yield ""

iterator genHasFieldProc(msg: Message, field: Field): string =
    # TODO: if map/seq, check also if there are values!
    yield &"proc has{field.name}*(message: {msg.names}): bool ="
    yield indent(&"result = contains(message.hasField, {field.number})", 4)
    yield ""

iterator genSetFieldProc(msg: Message, field: Field): string =
    yield &"proc set{field.name}*(message: {msg.names}, value: {field.fullType}) ="
    yield indent(&"message.{field.accessor} = value", 4)
    yield indent(&"incl(message.hasField, {field.number})", 4)
    for sibling in oneofSiblings(field):
        yield indent(&"excl(message.hasField, {sibling.number})", 4)
    yield ""

iterator genAddToFieldProc(msg: Message, field: Field): string =
    yield &"proc add{field.name}*(message: {msg.names}, value: {field.nimTypeName}) ="
    yield indent(&"add(message.{field.name}, value)", 4)
    yield indent(&"incl(message.hasField, {field.number})", 4)
    yield ""

iterator genFieldAccessorProcs(msg: Message, field: Field): string =
    yield &"proc {quoteReserved(field.name)}*(message: {msg.names}): {field.fullType} {{.inline.}} ="
    yield indent(&"message.{field.accessor}", 4)
    yield ""

    yield &"proc `{field.name}=`*(message: {msg.names}, value: {field.fullType}) {{.inline.}} ="
    yield indent(&"set{field.name}(message, value)", 4)
    yield ""

iterator genWriteMapKVProc(msg: Message): string =
    let
        key = mapKeyField(msg)
        value = mapValueField(msg)

    yield &"proc write{msg.names}KV(stream: ProtobufStream, key: {key.fullType}, value: {value.fullType}) ="

    yield indent(&"writeTag(stream, {key.number}, {wiretypeStr(key)})", 4)
    yield indent(&"write{key.typeName}(stream, key)", 4)

    yield indent(&"writeTag(stream, {value.number}, {wiretypeStr(value)})", 4)
    if isMessage(value):
        yield indent(&"writeVarint(stream, sizeOf{value.typeName}(value))", 4)
    yield indent(&"write{value.typeName}(stream, value)", 4)

    yield ""

iterator genWriteMessageProc(msg: Message): string =
    yield &"proc write{msg.names}*(stream: ProtobufStream, message: {msg.names}) ="
    for field in msg.fields:
        let writer = "write" & field.typeName
        if isMapEntry(field):
            yield indent(&"for key, value in message.{field.name}:", 4)
            yield indent(&"writeTag(stream, {field.number}, {wiretypeStr(field)})", 8)
            yield indent(&"writeVarint(stream, sizeOf{field.typeName}KV(key, value))", 8)
            yield indent(&"write{field.typeName}KV(stream, key, value)", 8)
        elif isRepeated(field):
            if field.packed:
                yield indent(&"if has{field.name}(message):", 4)
                yield indent(&"writeTag(stream, {field.number}, WireType.LengthDelimited)", 8)
                yield indent(&"writeVarint(stream, packedFieldSize(message.{field.name}, {field.fieldTypeStr}))", 8)
                yield indent(&"for value in message.{field.name}:", 8)
                yield indent(&"{writer}(stream, value)", 12)
            else:
                yield indent(&"for value in message.{field.name}:", 4)
                yield indent(&"writeTag(stream, {field.number}, {wiretypeStr(field)})", 8)
                if isMessage(field):
                    yield indent(&"writeVarint(stream, sizeOf{field.typeName}(value))", 8)
                yield indent(&"{writer}(stream, value)", 8)
        else:
            yield indent(&"if has{field.name}(message):", 4)
            yield indent(&"writeTag(stream, {field.number}, {wiretypeStr(field)})", 8)
            if isMessage(field):
                yield indent(&"writeVarint(stream, sizeOf{field.typeName}(message.{field.accessor}))", 8)
            yield indent(&"{writer}(stream, message.{field.accessor})", 8)

    if len(msg.fields) == 0:
        yield indent("discard", 4)

    yield ""

iterator genReadMapKVProc(msg: Message): string =
    let
        key = mapKeyField(msg)
        value = mapValueField(msg)

    yield &"proc read{msg.names}KV(stream: ProtobufStream, tbl: TableRef[{key.fullType}, {value.fullType}]) ="

    yield indent(&"var", 4)
    yield indent(&"key: {key.fullType}", 8)
    yield indent("gotKey = false", 8)
    yield indent(&"value: {value.fullType}", 8)
    yield indent("gotValue = false", 8)
    yield indent("while not atEnd(stream):", 4)
    yield indent("let", 8)
    yield indent("tag = readTag(stream)", 12)
    yield indent("wireType = getTagWireType(tag)", 12)
    yield indent("case getTagFieldNumber(tag)", 8)
    yield indent(&"of {key.number}:", 8)
    yield indent(&"key = read{key.typeName}(stream)", 12)
    yield indent("gotKey = true", 12)
    yield indent(&"of {value.number}:", 8)
    if isMessage(value):
        yield indent("let", 12)
        yield indent("size = readVarint(stream)", 16)
        yield indent("data = safeReadStr(stream, int(size))", 16)
        yield indent("pbs = newProtobufStream(newStringStream(data))", 16)
        yield indent(&"value = read{value.typeName}(pbs)", 12)
    else:
        yield indent(&"value = read{value.typeName}(stream)", 12)
    yield indent("gotValue = true", 12)
    yield indent("else: skipField(stream, wireType)", 8)
    yield indent("if not gotKey:", 4)
    yield indent(&"raise newException(Exception, \"missing key ({msg.names})\")", 8)
    yield indent("if not gotValue:", 4)
    yield indent(&"raise newException(Exception, \"missing value ({msg.names})\")", 8)
    yield indent("tbl[key] = value", 4)
    yield ""

iterator genReadMessageProc(msg: Message): string =
    yield &"proc read{msg.names}*(stream: ProtobufStream): {msg.names} ="
    yield indent(&"result = new{msg.names}()", 4)
    if len(msg.fields) > 0:
        yield indent("while not atEnd(stream):", 4)
        yield indent("let", 8)
        yield indent("tag = readTag(stream)", 12)
        yield indent("wireType = getTagWireType(tag)", 12)
        yield indent("case getTagFieldNumber(tag)", 8)
        yield indent("of 0:", 8)
        yield indent("raise newException(InvalidFieldNumberError, \"Invalid field number: 0\")", 12)
        for field in msg.fields:
            let
                reader = &"read{field.typeName}"
                setter =
                    if isRepeated(field):
                        &"add{field.name}"
                    else:
                        &"set{field.name}"
            yield indent(&"of {field.number}:", 8)
            if isRepeated(field):
                if isMapEntry(field):
                    yield indent(&"expectWireType(wireType, {field.wiretypeStr})", 12)
                    yield indent("let", 12)
                    yield indent("size = readVarint(stream)", 16)
                    yield indent("data = safeReadStr(stream, int(size))", 16)
                    yield indent("pbs = newProtobufStream(newStringStream(data))", 16)
                    yield indent(&"read{field.typeName}KV(pbs, result.{field.name})", 12)
                elif isNumeric(field):
                    yield indent(&"expectWireType(wireType, {field.wiretypeStr}, WireType.LengthDelimited)", 12)
                    yield indent("if wireType == WireType.LengthDelimited:", 12)
                    yield indent("let", 16)
                    yield indent("size = readVarint(stream)", 20)
                    yield indent("start = uint64(getPosition(stream))", 20)
                    yield indent("var consumed = 0'u64", 16)
                    yield indent("while consumed < size:", 16)
                    yield indent(&"{setter}(result, {reader}(stream))", 20)
                    yield indent("consumed = uint64(getPosition(stream)) - start", 20)
                    yield indent("if consumed != size:", 16)
                    yield indent("raise newException(Exception, \"packed field size mismatch\")", 20)
                    yield indent("else:", 12)
                    yield indent(&"{setter}(result, {reader}(stream))", 16)
                elif isMessage(field):
                    yield indent(&"expectWireType(wireType, {field.wiretypeStr})", 12)
                    yield indent("let", 12)
                    yield indent("size = readVarint(stream)", 16)
                    yield indent("data = safeReadStr(stream, int(size))", 16)
                    yield indent("pbs = newProtobufStream(newStringStream(data))", 16)
                    yield indent(&"{setter}(result, {reader}(pbs))", 12)
                else:
                    yield indent(&"expectWireType(wireType, {field.wiretypeStr})", 12)
                    yield indent(&"{setter}(result, {reader}(stream))", 12)
            else:
                yield indent(&"expectWireType(wireType, {field.wiretypeStr})", 12)
                if isMessage(field):
                    yield indent("let", 12)
                    yield indent("size = readVarint(stream)", 16)
                    yield indent("data = safeReadStr(stream, int(size))", 16)
                    yield indent("pbs = newProtobufStream(newStringStream(data))", 16)
                    yield indent(&"{setter}(result, {reader}(pbs))", 12)
                else:
                    yield indent(&"{setter}(result, {reader}(stream))", 12)
        yield indent("else: skipField(stream, wireType)", 8)
    yield ""

iterator genSizeOfMapKVProc(message: Message): string =
    let
        key = mapKeyField(message)
        value = mapValueField(message)

    yield &"proc sizeOf{message.names}KV(key: {key.fullType}, value: {value.fullType}): uint64 ="
    yield indent(&"result = result + sizeOf{key.typeName}(key)", 4)
    yield indent(&"result = result + sizeOfUInt32(uint32(makeTag({key.number}, {key.wiretypeStr})))", 4)
    yield indent(&"let valueSize = sizeOf{value.typeName}(value)", 4)
    yield indent(&"result = result + valueSize", 4)
    yield indent(&"result = result + sizeOfUInt32(uint32(makeTag({value.number}, {value.wiretypeStr})))", 4)
    if isMessage(value):
        yield indent(&"result = result + sizeOfUInt64(valueSize)", 4)
    yield ""

iterator genSizeOfMessageProc(msg: Message): string =
    yield &"proc sizeOf{msg.names}*(message: {msg.names}): uint64 ="
    for field in msg.fields:
        if isMapEntry(field):
            yield indent(&"if has{field.name}(message):", 4)
            yield indent(&"var sizeOfKV = 0'u64", 8)
            yield indent(&"for key, value in message.{field.name}:", 8)
            yield indent(&"sizeOfKV = sizeOfKV + sizeOf{field.typeName}KV(key, value)", 12)
            yield indent(&"let sizeOfTag = sizeOfUInt32(uint32(makeTag({field.number}, {wiretypeStr(field)})))", 8)
            yield indent("result = result + sizeOfKV + sizeOfTag + sizeOfUInt64(sizeOfKV)", 8)
        elif isRepeated(field):
            if isNumeric(field):
                yield indent(&"""
if has{field.name}(message):
    let
        sizeOfTag = sizeOfUInt32(uint32(makeTag({field.number}, WireType.LengthDelimited)))
        sizeOfData = packedFieldSize(message.{field.name}, {field.fieldTypeStr})
        sizeOfSize = sizeOfUInt64(sizeOfData)
    result = sizeOfTag + sizeOfData + sizeOfSize""", 4)
            else:
                yield indent(&"""
for value in message.{field.name}:
    let
        sizeOfValue = sizeOf{field.typeName}(value)
        sizeOfTag = sizeOfUInt32(uint32(makeTag({field.number}, {wiretypeStr(field)})))
    result = result + sizeOfValue + sizeOfTag
""", 4)
                if isMessage(field):
                    yield indent("result = result + sizeOfUInt64(sizeOfValue)", 8)
        else:
            yield indent(&"""
if has{field.name}(message):
    let
        sizeOfField = sizeOf{field.typeName}(message.{field.accessor})
        sizeOfTag = sizeOfUInt32(uint32(makeTag({field.number}, {wiretypeStr(field)})))
    result = result + sizeOfField + sizeOfTag""", 4)
            if isMessage(field):
                yield indent("result = result + sizeOfUInt64(sizeOfField)", 8)

    if len(msg.fields) == 0:
        yield indent("result = 0", 4)

    yield ""

iterator genMessageProcForwards(msg: Message): string =
    yield &"proc new{msg.names}*(): {msg.names}"
    yield &"proc write{msg.names}*(stream: ProtobufStream, message: {msg.names})"
    yield &"proc read{msg.names}*(stream: ProtobufStream): {msg.names}"
    yield &"proc sizeOf{msg.names}*(message: {msg.names}): uint64"

    if isMapEntry(msg):
        let
            key = mapKeyField(msg)
            value = mapValueField(msg)

        yield &"proc write{msg.names}KV(stream: ProtobufStream, key: {key.fullType}, value: {value.fullType})"
        yield &"proc read{msg.names}KV(stream: ProtobufStream, tbl: TableRef[{key.fullType}, {value.fullType}])"
        yield &"proc sizeOf{msg.names}KV(key: {key.fullType}, value: {value.fullType}): uint64"

iterator genProcs(msg: Message): string =
    for line in genNewMessageProc(msg): yield line

    for field in msg.fields:
        for line in genClearFieldProc(msg, field): yield line
        for line in genHasFieldProc(msg, field): yield line
        for line in genSetFieldProc(msg, field): yield line

        if isRepeated(field) and not isMapEntry(field):
            for line in genAddToFieldProc(msg, field): yield line

        for line in genFieldAccessorProcs(msg, field): yield line

    if isMapEntry(msg):
        for line in genSizeOfMapKVProc(msg): yield line
        for line in genWriteMapKVProc(msg): yield line
        for line in genReadMapKVProc(msg): yield line

    for line in genSizeOfMessageProc(msg): yield line
    for line in genWriteMessageProc(msg): yield line
    for line in genReadMessageProc(msg): yield line

    yield &"proc serialize*(message: {msg.names}): string ="
    yield indent("let", 4)
    yield indent("ss = newStringStream()", 8)
    yield indent("pbs = newProtobufStream(ss)", 8)
    yield indent(&"write{msg.names}(pbs, message)", 4)
    yield indent("result = ss.data", 4)
    yield ""

    yield &"proc new{msg.names}*(data: string): {msg.names} ="
    yield indent("let", 4)
    yield indent("ss = newStringStream(data)", 8)
    yield indent("pbs = newProtobufStream(ss)", 8)
    yield indent(&"result = read{msg.names}(pbs)", 4)
    yield ""

proc processFile(filename: string, fdesc: FileDescriptorProto,
                 otherFiles: TableRef[string, ProtoFile]): ProcessedFile =
    var (dir, name, _) = splitFile(filename)
    var pbfilename = (dir / name) & "_pb.nim"

    log(&"processing {filename}: {pbfilename}")

    new(result)
    result.name = pbfilename
    result.data = ""

    let parsed = parseFile(filename, fdesc)

    var hasMaps = false
    for message in parsed.messages:
        let tmp = fixMapEntry(parsed, message)
        if tmp:
            hasMaps = true

    addLine(result.data, "# Generated by protoc_gen_nim. Do not edit!")
    addLine(result.data, "")
    addLine(result.data, "import intsets")
    if hasMaps:
        addLine(result.data, "import tables")
        addLine(result.data, "export tables")
    addLine(result.data, "")
    addLine(result.data, "import protobuf/protobuf")
    addLine(result.data, "")

    for dep in fdesc.dependency:
        var (dir, depname, _) = splitFile(dep)

        if dir == "google/protobuf":
            dir = "protobuf/wkt"

        var deppbname = (dir / depname) & "_pb"
        addLine(result.data, &"import {deppbname}")

    if hasDependency(fdesc):
        addLine(result.data, "")

    addLine(result.data, "type")

    for e in parsed.enums:
        for line in genType(e): addLine(result.data, indent(line, 4))

    for message in parsed.messages:
        for line in genType(message): addLine(result.data, indent(line, 4))

    addLine(result.data, "")

    for e in parsed.enums:
        for line in genProcs(e):
            addLine(result.data, line)
        addLine(result.data, "")

    for message in sortDependencies(parsed.messages):
        for line in genMessageProcForwards(message):
            addLine(result.data, line)
        addLine(result.data, "")

    for message in sortDependencies(parsed.messages):
        for line in genProcs(message):
            addLine(result.data, line)
        addLine(result.data, "")

proc generateCode(request: CodeGeneratorRequest, response: CodeGeneratorResponse) =
    let otherFiles = newTable[string, ProtoFile]()

    for file in request.proto_file:
        add(otherFiles, file.name, parseFile(file.name, file))

    for filename in request.file_to_generate:
        for fdesc in request.proto_file:
            if fdesc.name == filename:
                let results = processFile(filename, fdesc, otherFiles)
                let f = newCodeGeneratorResponse_File()
                setName(f, results.name)
                setContent(f, results.data)
                addFile(response, f)

let pbsi = newProtobufStream(newFileStream(stdin))
let pbso = newProtobufStream(newFileStream(stdout))

let request = readCodeGeneratorRequest(pbsi)
let response = newCodeGeneratorResponse()

generateCode(request, response)

writeCodeGeneratorResponse(pbso, response)
