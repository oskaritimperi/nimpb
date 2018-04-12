import algorithm
import os
import pegs
import sequtils
import sets
import strformat
import strutils
import tables

import nimpb/wkt/descriptor_pb
import nimpb/utils

import ../nimpb

type
    Names = distinct seq[string]

    Enum = ref object
        names: Names
        values: seq[tuple[name: string, number: int]]
        defaultValue: string

    Field = ref object
        number: int
        name: string
        label: google_protobuf_FieldDescriptorProto_Label
        ftype: google_protobuf_FieldDescriptorProto_Type
        typeName: string
        packed: bool
        oneof: Oneof
        mapEntry: Message
        defaultValue: string
        message: Message
        jsonName: string

    Message = ref object
        names: Names
        fields: seq[Field]
        oneofs: seq[Oneof]
        mapEntry: bool
        file: ProtoFile

    Oneof = ref object
        name: string
        fields: seq[Field]

    ProcessedFile = ref object
        name: string
        data: string

    ProtoFile = ref object
        fdesc: google_protobuf_FileDescriptorProto
        enums: seq[Enum]
        messages: seq[Message]
        syntax: Syntax
        dependencies: seq[ProtoFile]
        serviceGenerator: ServiceGenerator

    Syntax {.pure.} = enum
        Proto2
        Proto3

    ServiceGenerator* = proc (service: Service): string

    Service* = ref object
        name*: string
        package*: string
        methods*: seq[ServiceMethod]

    ServiceMethod* = ref object
        name*: string
        inputType*: string
        outputType*: string
        clientStreaming*: bool
        serverStreaming*: bool

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
    result = field.label == google_protobuf_FieldDescriptorProtoLabel.LabelRepeated

proc isMessage(field: Field): bool =
    result = field.ftype == google_protobuf_FieldDescriptorProtoType.TypeMessage

proc isEnum(field: Field): bool =
    result = field.ftype == google_protobuf_FieldDescriptorProtoType.TypeEnum

proc isNumeric(field: Field): bool =
    case field.ftype
    of google_protobuf_FieldDescriptorProtoType.TypeDouble, google_protobuf_FieldDescriptorProtoType.TypeFloat,
       google_protobuf_FieldDescriptorProtoType.TypeInt64, google_protobuf_FieldDescriptorProtoType.TypeUInt64,
       google_protobuf_FieldDescriptorProtoType.TypeInt32, google_protobuf_FieldDescriptorProtoType.TypeFixed64,
       google_protobuf_FieldDescriptorProtoType.TypeFixed32, google_protobuf_FieldDescriptorProtoType.TypeBool,
       google_protobuf_FieldDescriptorProtoType.TypeUInt32, google_protobuf_FieldDescriptorProtoType.TypeEnum,
       google_protobuf_FieldDescriptorProtoType.TypeSFixed32, google_protobuf_FieldDescriptorProtoType.TypeSFixed64,
       google_protobuf_FieldDescriptorProtoType.TypeSInt32, google_protobuf_FieldDescriptorProtoType.TypeSInt64:
       result = true
    else: discard

proc isMapEntry(message: Message): bool =
    result = message.mapEntry

proc isMapEntry(field: Field): bool =
    result = field.mapEntry != nil

proc nimTypeName(field: Field): string =
    case field.ftype
    of google_protobuf_FieldDescriptorProtoType.TypeDouble: result = "float64"
    of google_protobuf_FieldDescriptorProtoType.TypeFloat: result = "float32"
    of google_protobuf_FieldDescriptorProtoType.TypeInt64: result = "int64"
    of google_protobuf_FieldDescriptorProtoType.TypeUInt64: result = "uint64"
    of google_protobuf_FieldDescriptorProtoType.TypeInt32: result = "int32"
    of google_protobuf_FieldDescriptorProtoType.TypeFixed64: result = "uint64"
    of google_protobuf_FieldDescriptorProtoType.TypeFixed32: result = "uint32"
    of google_protobuf_FieldDescriptorProtoType.TypeBool: result = "bool"
    of google_protobuf_FieldDescriptorProtoType.TypeString: result = "string"
    of google_protobuf_FieldDescriptorProtoType.TypeGroup: result = ""
    of google_protobuf_FieldDescriptorProtoType.TypeMessage: result = field.typeName
    of google_protobuf_FieldDescriptorProtoType.TypeBytes: result = "bytes"
    of google_protobuf_FieldDescriptorProtoType.TypeUInt32: result = "uint32"
    of google_protobuf_FieldDescriptorProtoType.TypeEnum: result = field.typeName
    of google_protobuf_FieldDescriptorProtoType.TypeSFixed32: result = "int32"
    of google_protobuf_FieldDescriptorProtoType.TypeSFixed64: result = "int64"
    of google_protobuf_FieldDescriptorProtoType.TypeSInt32: result = "int32"
    of google_protobuf_FieldDescriptorProtoType.TypeSInt64: result = "int64"

proc mapKeyType(field: Field): string =
    for f in field.mapEntry.fields:
        if f.name == "key":
            return f.nimTypeName

proc mapValueField(field: Field): Field =
    for f in field.mapEntry.fields:
        if f.name == "value":
            return f

proc mapValueType(field: Field): string =
    for f in field.mapEntry.fields:
        if f.name == "value":
            return f.nimTypeName

proc `$`(ft: google_protobuf_FieldDescriptorProtoType): string =
    case ft
    of google_protobuf_FieldDescriptorProtoType.TypeDouble: result = "Double"
    of google_protobuf_FieldDescriptorProtoType.TypeFloat: result = "Float"
    of google_protobuf_FieldDescriptorProtoType.TypeInt64: result = "Int64"
    of google_protobuf_FieldDescriptorProtoType.TypeUInt64: result = "UInt64"
    of google_protobuf_FieldDescriptorProtoType.TypeInt32: result = "Int32"
    of google_protobuf_FieldDescriptorProtoType.TypeFixed64: result = "Fixed64"
    of google_protobuf_FieldDescriptorProtoType.TypeFixed32: result = "Fixed32"
    of google_protobuf_FieldDescriptorProtoType.TypeBool: result = "Bool"
    of google_protobuf_FieldDescriptorProtoType.TypeString: result = "String"
    of google_protobuf_FieldDescriptorProtoType.TypeGroup: result = "Group"
    of google_protobuf_FieldDescriptorProtoType.TypeMessage: result = "Message"
    of google_protobuf_FieldDescriptorProtoType.TypeBytes: result = "Bytes"
    of google_protobuf_FieldDescriptorProtoType.TypeUInt32: result = "UInt32"
    of google_protobuf_FieldDescriptorProtoType.TypeEnum: result = "Enum"
    of google_protobuf_FieldDescriptorProtoType.TypeSFixed32: result = "SFixed32"
    of google_protobuf_FieldDescriptorProtoType.TypeSFixed64: result = "SFixed64"
    of google_protobuf_FieldDescriptorProtoType.TypeSInt32: result = "SInt32"
    of google_protobuf_FieldDescriptorProtoType.TypeSInt64: result = "SInt64"

proc defaultValue(ftype: google_protobuf_FieldDescriptorProto_Type): string =
    case ftype
    of google_protobuf_FieldDescriptorProtoType.TypeDouble: result = "0"
    of google_protobuf_FieldDescriptorProtoType.TypeFloat: result = "0"
    of google_protobuf_FieldDescriptorProtoType.TypeInt64: result = "0"
    of google_protobuf_FieldDescriptorProtoType.TypeUInt64: result = "0"
    of google_protobuf_FieldDescriptorProtoType.TypeInt32: result = "0"
    of google_protobuf_FieldDescriptorProtoType.TypeFixed64: result = "0"
    of google_protobuf_FieldDescriptorProtoType.TypeFixed32: result = "0"
    of google_protobuf_FieldDescriptorProtoType.TypeBool: result = "false"
    of google_protobuf_FieldDescriptorProtoType.TypeString: result = "\"\""
    of google_protobuf_FieldDescriptorProtoType.TypeGroup: result = ""
    of google_protobuf_FieldDescriptorProtoType.TypeMessage: result = "nil"
    of google_protobuf_FieldDescriptorProtoType.TypeBytes: result = "bytes(\"\")"
    of google_protobuf_FieldDescriptorProtoType.TypeUInt32: result = "0"
    of google_protobuf_FieldDescriptorProtoType.TypeEnum: result = "0"
    of google_protobuf_FieldDescriptorProtoType.TypeSFixed32: result = "0"
    of google_protobuf_FieldDescriptorProtoType.TypeSFixed64: result = "0"
    of google_protobuf_FieldDescriptorProtoType.TypeSInt32: result = "0"
    of google_protobuf_FieldDescriptorProtoType.TypeSInt64: result = "0"

proc findEnum(file: ProtoFile, typeName: string): Enum =
    for e in file.enums:
        if $e.names == typeName:
            return e
    for dep in file.dependencies:
        result = findEnum(dep, typeName)
        if result != nil:
            break

proc defaultValue(field: Field): string =
    if field.defaultValue != nil:
        if isEnum(field):
            return &"{field.typeName}.{field.defaultValue}"
        elif field.ftype == google_protobuf_FieldDescriptorProtoType.TypeString:
            return escape(field.defaultValue)
        else:
            return field.defaultValue
    elif isMapEntry(field):
        return &"newTable[{field.mapKeyType}, {field.mapValueType}]()"
    elif isRepeated(field):
        return "@[]"
    elif isEnum(field):
        let e = findEnum(field.message.file, field.typeName)
        if e != nil:
            result = e.defaultValue
        else:
            result = &"cast[{field.typeName}](0)"
    else:
        result = defaultValue(field.ftype)

proc wiretypeStr(field: Field): string =
    result = "WireType."
    case field.ftype
    of google_protobuf_FieldDescriptorProtoType.TypeDouble: result &= "Fixed64"
    of google_protobuf_FieldDescriptorProtoType.TypeFloat: result &= "Fixed32"
    of google_protobuf_FieldDescriptorProtoType.TypeInt64: result &= "Varint"
    of google_protobuf_FieldDescriptorProtoType.TypeUInt64: result &= "Varint"
    of google_protobuf_FieldDescriptorProtoType.TypeInt32: result &= "Varint"
    of google_protobuf_FieldDescriptorProtoType.TypeFixed64: result &= "Fixed64"
    of google_protobuf_FieldDescriptorProtoType.TypeFixed32: result &= "Fixed32"
    of google_protobuf_FieldDescriptorProtoType.TypeBool: result &= "Varint"
    of google_protobuf_FieldDescriptorProtoType.TypeString: result &= "LengthDelimited"
    of google_protobuf_FieldDescriptorProtoType.TypeGroup: result &= ""
    of google_protobuf_FieldDescriptorProtoType.TypeMessage: result &= "LengthDelimited"
    of google_protobuf_FieldDescriptorProtoType.TypeBytes: result &= "LengthDelimited"
    of google_protobuf_FieldDescriptorProtoType.TypeUInt32: result &= "Varint"
    of google_protobuf_FieldDescriptorProtoType.TypeEnum: result &= &"Varint"
    of google_protobuf_FieldDescriptorProtoType.TypeSFixed32: result &= "Fixed32"
    of google_protobuf_FieldDescriptorProtoType.TypeSFixed64: result &= "Fixed64"
    of google_protobuf_FieldDescriptorProtoType.TypeSInt32: result &= "Varint"
    of google_protobuf_FieldDescriptorProtoType.TypeSInt64: result &= "Varint"

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

proc writeProc(field: Field): string =
    if isMapEntry(field):
        result = &"write{field.typeName}KV"
    elif isMessage(field):
        result = "writeMessage"
    elif isEnum(field):
        result = "protoWriteEnum"
    else:
        result = &"protoWrite{field.typeName}"

proc readProc(field: Field): string =
    if isMapEntry(field):
        result = &"read{field.typeName}KV"
    elif isEnum(field):
        result = &"protoReadEnum[{field.typeName}]"
    elif isMessage(field):
        result = &"read{field.typeName}"
    else:
        result = &"protoRead{field.typeName}"

proc sizeOfProc(field: Field): string =
    if isMapEntry(field):
        result = &"sizeOf{field.typeName}KV"
    elif isEnum(field):
        result = &"sizeOfEnum[{field.typeName}]"
    else:
        result = &"sizeOf{field.typeName}"

proc newField(file: ProtoFile, message: Message, desc: google_protobuf_FieldDescriptorProto): Field =
    new(result)

    result.name = toCamelCase(desc.name)
    result.number = desc.number
    result.label = desc.label
    result.ftype = desc.ftype
    result.typeName = ""
    result.packed = false
    result.mapEntry = nil
    result.message = message

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

    if hasDefaultValue(desc):
        result.defaultValue = desc.default_value

    if hasJsonName(desc):
        result.jsonName = desc.jsonName

    log(&"newField {result.name} {$result.ftype} {result.typeName} PACKED={result.packed} SYNTAX={file.syntax}")

proc newOneof(name: string): Oneof =
    new(result)
    result.fields = @[]
    result.name = toCamelCase(name)

proc newMessage(file: ProtoFile, names: Names, desc: google_protobuf_DescriptorProto): Message =
    new(result)

    result.names = names
    result.fields = @[]
    result.oneofs = @[]
    result.mapEntry = false
    result.file = file

    if hasOptions(desc) and hasMapEntry(desc.options):
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

proc newEnum(names: Names, desc: google_protobuf_EnumDescriptorProto): Enum =
    new(result)

    result.names = names & desc.name
    result.values = @[]

    log(&"newEnum {$result.names}")

    for value in desc.value:
        add(result.values, (value.name, int(value.number)))

    result.defaultValue = &"{result.names}.{result.values[0].name}"

    type EnumValue = tuple[name: string, number: int]

    sort(result.values, proc (x, y: EnumValue): int =
        system.cmp(x.number, y.number)
    )

proc newService(service: google_protobuf_ServiceDescriptorProto,
                file: ProtoFile): Service =
    new(result)
    result.name = service.name
    result.package = file.fdesc.package
    result.methods = @[]

    for meth in service.fmethod:
        var m: ServiceMethod
        new(m)

        m.name = meth.name
        m.inputType = $initNamesFromTypeName(meth.inputType)
        m.outputType = $initNamesFromTypeName(meth.outputType)
        m.clientStreaming = meth.clientStreaming
        m.serverStreaming = meth.serverStreaming

        add(result.methods, m)

iterator messages(desc: google_protobuf_DescriptorProto, names: Names): tuple[names: Names, desc: google_protobuf_DescriptorProto] =
    var stack: seq[tuple[names: Names, desc: google_protobuf_DescriptorProto]] = @[]

    for nested in desc.nested_type:
        add(stack, (names, nested))

    while len(stack) > 0:
        let (names, submsg) = pop(stack)

        let subnames = names & submsg.name
        yield (subnames, submsg)

        for desc in submsg.nested_type:
            add(stack, (subnames, desc))

iterator messages(fdesc: google_protobuf_FileDescriptorProto, names: Names): tuple[names: Names, desc: google_protobuf_DescriptorProto] =
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

proc parseFile(name: string, fdesc: google_protobuf_FileDescriptorProto): ProtoFile =
    log(&"parsing {name}")

    new(result)

    result.fdesc = fdesc
    result.messages = @[]
    result.enums = @[]
    result.dependencies = @[]

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
    if not isMapEntry(message):
        yield &"{message.names}* = ref {message.names}Obj"
        yield &"{message.names}Obj* = object of Message"

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

iterator genNewMessageProc(msg: Message): string =
    yield &"proc new{msg.names}*(): {msg.names} ="
    yield indent("new(result)", 4)
    yield indent("initMessage(result[])", 4)
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
    var numbers: seq[int] = @[field.number]
    for sibling in oneofSiblings(field):
        add(numbers, sibling.number)
    yield indent(&"clearFields(message, [{join(numbers, \", \")}])", 4)
    yield ""

iterator genHasFieldProc(msg: Message, field: Field): string =
    yield &"proc has{field.name}*(message: {msg.names}): bool ="
    var check = indent(&"result = hasField(message, {field.number})", 4)
    if isRepeated(field) or isMapEntry(field):
        check = &"{check} or (len(message.{field.accessor}) > 0)"
    yield check
    yield ""

iterator genSetFieldProc(msg: Message, field: Field): string =
    yield &"proc set{field.name}*(message: {msg.names}, value: {field.fullType}) ="
    yield indent(&"message.{field.accessor} = value", 4)
    yield indent(&"setField(message, {field.number})", 4)
    var numbers: seq[int] = @[]
    for sibling in oneofSiblings(field):
        add(numbers, sibling.number)
    if len(numbers) > 0:
        yield indent(&"clearFields(message, [{join(numbers, \", \")}])", 4)
    yield ""

iterator genAddToFieldProc(msg: Message, field: Field): string =
    yield &"proc add{field.name}*(message: {msg.names}, value: {field.nimTypeName}) ="
    yield indent(&"add(message.{field.name}, value)", 4)
    yield indent(&"setField(message, {field.number})", 4)
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

    yield &"proc write{msg.names}KV(stream: Stream, key: {key.fullType}, value: {value.fullType}) ="
    yield indent(&"{key.writeProc}(stream, key, {key.number})", 4)
    yield indent(&"{value.writeProc}(stream, value, {value.number})", 4)
    yield ""

iterator genWriteMessageProc(msg: Message): string =
    yield &"proc write{msg.names}*(stream: Stream, message: {msg.names}) ="

    for field in msg.fields:
        if isMapEntry(field):
            yield indent(&"for key, value in message.{field.name}:", 4)
            yield indent(&"writeTag(stream, {field.number}, {wiretypeStr(field)})", 8)
            yield indent(&"writeVarint(stream, {field.sizeOfProc}(key, value))", 8)
            yield indent(&"{field.writeProc}(stream, key, value)", 8)
        elif isRepeated(field):
            if field.packed:
                yield indent(&"if has{field.name}(message):", 4)
                yield indent(&"writeTag(stream, {field.number}, WireType.LengthDelimited)", 8)
                yield indent(&"writeVarint(stream, packedFieldSize(message.{field.name}, {field.fieldTypeStr}))", 8)
                yield indent(&"for value in message.{field.name}:", 8)
                yield indent(&"{field.writeProc}(stream, value)", 12)
            else:
                yield indent(&"for value in message.{field.name}:", 4)
                yield indent(&"{field.writeProc}(stream, value, {field.number})", 8)
        else:
            yield indent(&"if has{field.name}(message):", 4)
            yield indent(&"{field.writeProc}(stream, message.{field.accessor}, {field.number})", 8)

    yield indent("writeUnknownFields(stream, message)", 4)

    yield ""

iterator genReadMapKVProc(msg: Message): string =
    let
        key = mapKeyField(msg)
        value = mapValueField(msg)

    yield &"proc read{msg.names}KV(stream: Stream, tbl: TableRef[{key.fullType}, {value.fullType}]) ="

    yield indent(&"var", 4)
    yield indent(&"key: {key.fullType}", 8)
    yield indent("gotKey = false", 8)
    yield indent(&"value: {value.fullType}", 8)
    yield indent("gotValue = false", 8)
    yield indent("while not atEnd(stream):", 4)
    yield indent("let", 8)
    yield indent("tag = readTag(stream)", 12)
    yield indent("wireType = wireType(tag)", 12)
    yield indent("case fieldNumber(tag)", 8)
    yield indent(&"of {key.number}:", 8)
    yield indent(&"key = {key.readProc}(stream)", 12)
    yield indent("gotKey = true", 12)
    yield indent(&"of {value.number}:", 8)
    if isMessage(value):
        yield indent("let", 12)
        yield indent("size = readVarint(stream)", 16)
        yield indent("data = safeReadStr(stream, int(size))", 16)
        yield indent("pbs = newStringStream(data)", 16)
        yield indent(&"value = {value.readProc}(pbs)", 12)
    else:
        yield indent(&"value = {value.readProc}(stream)", 12)
    yield indent("gotValue = true", 12)
    yield indent("else: skipField(stream, wireType)", 8)
    yield indent("if not gotKey:", 4)
    yield indent(&"raise newException(Exception, \"missing key\")", 8)
    yield indent("if not gotValue:", 4)
    yield indent(&"raise newException(Exception, \"missing value\")", 8)
    yield indent("tbl[key] = value", 4)
    yield ""

iterator genReadMessageProc(msg: Message): string =
    yield &"proc read{msg.names}*(stream: Stream): {msg.names} ="
    yield indent(&"result = new{msg.names}()", 4)
    yield indent("while not atEnd(stream):", 4)
    yield indent("let", 8)
    yield indent("tag = readTag(stream)", 12)
    yield indent("wireType = wireType(tag)", 12)
    yield indent("case fieldNumber(tag)", 8)
    yield indent("of 0:", 8)
    yield indent("raise newException(InvalidFieldNumberError, \"Invalid field number: 0\")", 12)
    for field in msg.fields:
        let
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
                yield indent("pbs = newStringStream(data)", 16)
                yield indent(&"{field.readProc}(pbs, result.{field.name})", 12)
            elif isNumeric(field):
                yield indent(&"expectWireType(wireType, {field.wiretypeStr}, WireType.LengthDelimited)", 12)
                yield indent("if wireType == WireType.LengthDelimited:", 12)
                yield indent("let", 16)
                yield indent("size = readVarint(stream)", 20)
                yield indent("start = uint64(getPosition(stream))", 20)
                yield indent("var consumed = 0'u64", 16)
                yield indent("while consumed < size:", 16)
                yield indent(&"{setter}(result, {field.readProc}(stream))", 20)
                yield indent("consumed = uint64(getPosition(stream)) - start", 20)
                yield indent("if consumed != size:", 16)
                yield indent("raise newException(Exception, \"packed field size mismatch\")", 20)
                yield indent("else:", 12)
                yield indent(&"{setter}(result, {field.readProc}(stream))", 16)
            elif isMessage(field):
                yield indent(&"expectWireType(wireType, {field.wiretypeStr})", 12)
                yield indent(&"let data = readLengthDelimited(stream)", 12)
                yield indent(&"{setter}(result, new{field.typeName}(data))", 12)
            else:
                yield indent(&"expectWireType(wireType, {field.wiretypeStr})", 12)
                yield indent(&"{setter}(result, {field.readProc}(stream))", 12)
        else:
            yield indent(&"expectWireType(wireType, {field.wiretypeStr})", 12)
            if isMessage(field):
                yield indent("let data = readLengthDelimited(stream)", 12)
                yield indent(&"{setter}(result, new{field.typeName}(data))", 12)
            else:
                yield indent(&"{setter}(result, {field.readProc}(stream))", 12)
    yield indent("else: readUnknownField(stream, result, tag)", 8)
    yield ""

iterator genSizeOfMapKVProc(message: Message): string =
    let
        key = mapKeyField(message)
        value = mapValueField(message)

    yield &"proc sizeOf{message.names}KV(key: {key.fullType}, value: {value.fullType}): uint64 ="

    # Key (cannot be message or other complex field)
    yield indent(&"result = result + sizeOfTag({key.number}, {key.wiretypeStr})", 4)
    yield indent(&"result = result + {key.sizeOfProc}(key)", 4)

    # Value
    yield indent(&"result = result + sizeOfTag({value.number}, {value.wiretypeStr})", 4)
    if isMessage(value):
        yield indent(&"result = result + sizeOfLengthDelimited({value.sizeOfProc}(value))", 4)
    else:
        yield indent(&"result = result + {value.sizeOfProc}(value)", 4)

    yield ""

iterator genSizeOfMessageProc(msg: Message): string =
    yield &"proc sizeOf{msg.names}*(message: {msg.names}): uint64 ="
    for field in msg.fields:
        if isMapEntry(field):
            yield indent(&"if has{field.name}(message):", 4)
            yield indent(&"var sizeOfKV = 0'u64", 8)
            yield indent(&"for key, value in message.{field.name}:", 8)
            yield indent(&"sizeOfKV = sizeOfKV + {field.sizeOfProc}(key, value)", 12)
            yield indent(&"result = result + sizeOfTag({field.number}, {field.wiretypeStr})", 8)
            yield indent(&"result = result + sizeOfLengthDelimited(sizeOfKV)", 8)
        elif isRepeated(field):
            if isNumeric(field):
                yield indent(&"if has{field.name}(message):", 4)
                yield indent(&"result = result + sizeOfTag({field.number}, WireType.LengthDelimited)", 8)
                yield indent(&"result = result + sizeOfLengthDelimited(packedFieldSize(message.{field.name}, {field.fieldTypeStr}))", 8)
            else:
                yield indent(&"for value in message.{field.name}:", 4)
                yield indent(&"result = result + sizeOfTag({field.number}, {field.wiretypeStr})", 8)
                if isMessage(field):
                    yield indent(&"result = result + sizeOfLengthDelimited({field.sizeOfProc}(value))", 8)
                else:
                    yield indent(&"result = result + {field.sizeOfProc}(value)", 8)
        else:
            yield indent(&"if has{field.name}(message):", 4)
            yield indent(&"result = result + sizeOfTag({field.number}, {field.wiretypeStr})", 8)
            if isMessage(field):
                yield indent(&"result = result + sizeOfLengthDelimited({field.sizeOfProc}(message.{field.accessor}))", 8)
            else:
                yield indent(&"result = result + {field.sizeOfProc}(message.{field.accessor})", 8)

    yield indent("result = result + sizeOfUnknownFields(message)", 4)

    yield ""

proc shouldGenerateJsonProcs(typeName: string): bool =
    const wktsHavingCustomProcs = [
        "google_protobuf_Any",
        "google_protobuf_BoolValue",
        "google_protobuf_BytesValue",
        "google_protobuf_DoubleValue",
        "google_protobuf_Duration",
        "google_protobuf_FieldMask",
        "google_protobuf_FloatValue",
        "google_protobuf_Int32Value",
        "google_protobuf_Int64Value",
        "google_protobuf_ListValue",
        "google_protobuf_NullValue",
        "google_protobuf_StringValue",
        "google_protobuf_Struct",
        "google_protobuf_Timestamp",
        "google_protobuf_UInt32Value",
        "google_protobuf_UInt64Value",
        "google_protobuf_Value",
    ]

    return typeName notin wktsHavingCustomProcs

iterator genMessageToJsonProc(msg: Message): string =
    yield &"proc toJson*(message: {msg.names}): JsonNode ="
    yield indent("result = newJObject()", 4)

    proc fieldToJson(field: Field, v: string): string =
        case field.ftype
        of google_protobuf_FieldDescriptorProto_Type.TypeMessage,
           google_protobuf_FieldDescriptorProto_Type.TypeInt64,
           google_protobuf_FieldDescriptorProto_Type.TypeUInt64,
           google_protobuf_FieldDescriptorProto_Type.TypeSFixed64,
           google_protobuf_FieldDescriptorProto_Type.TypeFixed64,
           google_protobuf_FieldDescriptorProto_Type.TypeDouble,
           google_protobuf_FieldDescriptorProto_Type.TypeFloat:
            result = &"toJson({v})"
        of google_protobuf_FieldDescriptorProto_Type.TypeEnum:
            result = &"%(${v})"
        else:
            result = &"%{v}"

    for field in msg.fields:
        yield indent(&"if has{field.name}(message):", 4)
        if isMapEntry(field):
            yield indent("let obj = newJObject()", 8)
            yield indent(&"for key, value in message.{field.name}:", 8)
            let f = mapValueField(field)
            let j = fieldToJson(f, "value")
            yield indent(&"obj[$key] = {j}", 12)
            yield indent(&"result[\"{field.jsonName}\"] = obj", 8)
        elif isRepeated(field):
            yield indent(&"let arr = newJArray()", 8)
            yield indent(&"for value in message.{field.name}:", 8)
            let v = fieldToJson(field, "value")
            yield indent(&"add(arr, {v})", 12)
            yield indent(&"result[\"{field.jsonName}\"] = arr", 8)
        else:
            let v = fieldToJson(field, &"message.{field.name}")
            yield indent(&"result[\"{field.jsonName}\"] = {v}", 8)

    yield ""

iterator genMessageProcForwards(msg: Message): string =
    # TODO: can we be more intelligent and only forward declare the minimum set
    # of procs?
    if not isMapEntry(msg):
        yield &"proc new{msg.names}*(): {msg.names}"
        yield &"proc new{msg.names}*(data: string): {msg.names}"
        yield &"proc write{msg.names}*(stream: Stream, message: {msg.names})"
        yield &"proc read{msg.names}*(stream: Stream): {msg.names}"
        yield &"proc sizeOf{msg.names}*(message: {msg.names}): uint64"
        if shouldGenerateJsonProcs($msg.names):
            yield &"proc toJson*(message: {msg.names}): JsonNode"
    else:
        let
            key = mapKeyField(msg)
            value = mapValueField(msg)

        yield &"proc write{msg.names}KV(stream: Stream, key: {key.fullType}, value: {value.fullType})"
        yield &"proc read{msg.names}KV(stream: Stream, tbl: TableRef[{key.fullType}, {value.fullType}])"
        yield &"proc sizeOf{msg.names}KV(key: {key.fullType}, value: {value.fullType}): uint64"

iterator genProcs(msg: Message): string =
    if isMapEntry(msg):
        for line in genSizeOfMapKVProc(msg): yield line
        for line in genWriteMapKVProc(msg): yield line
        for line in genReadMapKVProc(msg): yield line
    else:
        for line in genNewMessageProc(msg): yield line

        for field in msg.fields:
            for line in genClearFieldProc(msg, field): yield line
            for line in genHasFieldProc(msg, field): yield line
            for line in genSetFieldProc(msg, field): yield line

            if isRepeated(field) and not isMapEntry(field):
                for line in genAddToFieldProc(msg, field): yield line

            for line in genFieldAccessorProcs(msg, field): yield line

        for line in genSizeOfMessageProc(msg): yield line
        for line in genWriteMessageProc(msg): yield line
        for line in genReadMessageProc(msg): yield line

        if shouldGenerateJsonProcs($msg.names):
            for line in genMessageToJsonProc(msg): yield line

        yield &"proc serialize*(message: {msg.names}): string ="
        yield indent("let", 4)
        yield indent("ss = newStringStream()", 8)
        yield indent(&"write{msg.names}(ss, message)", 4)
        yield indent("result = ss.data", 4)
        yield ""

        yield &"proc new{msg.names}*(data: string): {msg.names} ="
        yield indent("let", 4)
        yield indent("ss = newStringStream(data)", 8)
        yield indent(&"result = read{msg.names}(ss)", 4)
        yield ""

proc processFile(fdesc: google_protobuf_FileDescriptorProto,
                 otherFiles: TableRef[string, ProtoFile],
                 serviceGenerator: ServiceGenerator): ProcessedFile =
    var (dir, name, _) = splitFile(fdesc.name)
    var pbfilename = (dir / name) & "_pb.nim"

    log(&"processing {fdesc.name}: {pbfilename}")

    new(result)
    result.name = pbfilename
    result.data = ""

    let parsed = parseFile(fdesc.name, fdesc)

    for dep in fdesc.dependency:
        if dep in otherFiles:
            add(parsed.dependencies, otherFiles[dep])

    var hasMaps = false
    for message in parsed.messages:
        let tmp = fixMapEntry(parsed, message)
        if tmp:
            hasMaps = true

    addLine(result.data, "# Generated by protoc_gen_nim. Do not edit!")
    addLine(result.data, "")
    addLine(result.data, "import base64")
    addLine(result.data, "import intsets")
    addLine(result.data, "import json")
    if hasMaps:
        addLine(result.data, "import tables")
        addLine(result.data, "export tables")
    addLine(result.data, "")
    addLine(result.data, "import nimpb/nimpb")
    addLine(result.data, "import nimpb/json as nimpb_json")
    addLine(result.data, "")

    for dep in fdesc.dependency:
        var (dir, depname, _) = splitFile(dep)

        if dir == "google/protobuf":
            dir = "nimpb/wkt"

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

    for message in sortDependencies(parsed.messages):
        for line in genMessageProcForwards(message):
            addLine(result.data, line)
        addLine(result.data, "")

    for message in sortDependencies(parsed.messages):
        for line in genProcs(message):
            addLine(result.data, line)
        addLine(result.data, "")

    if serviceGenerator != nil:
        for serviceDesc in fdesc.service:
            let service = newService(serviceDesc, parsed)
            addLine(result.data, "")
            add(result.data, serviceGenerator(service))

proc processFileDescriptorSet*(filename: string,
                               outdir: string,
                               protos: openArray[string],
                               serviceGenerator: ServiceGenerator) =
    let s = newFileStream(filename, fmRead)

    let fileSet = readgoogle_protobuf_FileDescriptorSet(s)

    var otherFiles = newTable[string, ProtoFile]()

    for file in fileSet.file:
        add(otherFiles, file.name, parseFile(file.name, file))

    # Protoc does not provide full paths for files in FileDescriptorSet. So it
    # can be that fileSet.file.name might match any file in protos. So we will
    # try to match the bare name and the named joined with the path of the first
    # file.
    let basePath = parentDir(protos[0])

    for file in fileSet.file:
        if (file.name in protos) or ((basePath / file.name) in protos):
            let processedFile = processFile(file, otherFiles, serviceGenerator)

            let fullPath = outdir / processedFile.name

            createDir(parentDir(fullPath))

            writeFile(fullPath, processedFile.data)
