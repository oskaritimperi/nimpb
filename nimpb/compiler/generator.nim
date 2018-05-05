## This module implements Nim code generation from protoc output.

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
        protoName: string

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

    ServiceGenerator* = ref object of RootObj
        ## If set, the service will be generated in it's own file. The filename
        ## where the service will be generated will be <basename>_<suffix>.nim,
        ## where basename is the name of the proto file without the .proto
        ## suffix.
        fileSuffix*: string

        ## This will be set to the basename (without extension) of the file
        ## where the serialization code will be generated. It will be set before
        ## any callbacks are called. You can use this for importing if you
        ## generate a new file for the service by setting fileSuffix.
        fileName*: string

        ## This will be called once per proto file.
        genImports*: proc (): string

        ## This will be called once per service definition.
        genService*: proc (service: Service): string

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

const
    WktsWithExtras = [
        "any",
        "duration",
        "field_mask",
        "struct",
        "timestamp",
        "wrappers",
    ]

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

proc isFloat(field: Field): bool =
    case field.ftype
    of google_protobuf_FieldDescriptorProtoType.TypeDouble: result = true
    of google_protobuf_FieldDescriptorProtoType.TypeFloat: result = true
    else: result = false

proc isUnsigned(field: Field): bool =
    case field.ftype
    of google_protobuf_FieldDescriptorProtoType.TypeUInt64,
       google_protobuf_FieldDescriptorProtoType.TypeFixed64,
       google_protobuf_FieldDescriptorProtoType.TypeFixed32,
       google_protobuf_FieldDescriptorProtoType.TypeUInt32:
       result = true
    else: result = false

proc isBool(field: Field): bool =
    result = field.ftype == google_protobuf_FieldDescriptorProtoType.TypeBool

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
    of google_protobuf_FieldDescriptorProtoType.TypeBytes: result = "seq[byte]"
    of google_protobuf_FieldDescriptorProtoType.TypeUInt32: result = "uint32"
    of google_protobuf_FieldDescriptorProtoType.TypeEnum: result = field.typeName
    of google_protobuf_FieldDescriptorProtoType.TypeSFixed32: result = "int32"
    of google_protobuf_FieldDescriptorProtoType.TypeSFixed64: result = "int64"
    of google_protobuf_FieldDescriptorProtoType.TypeSInt32: result = "int32"
    of google_protobuf_FieldDescriptorProtoType.TypeSInt64: result = "int64"

proc mapKeyField(field: Field): Field =
    for f in field.mapEntry.fields:
        if f.name == "key":
            return f

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
    of google_protobuf_FieldDescriptorProtoType.TypeBytes: result = "@[]"
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

proc shouldGenerateHasField(msg: Message, field: Field): bool =
    if msg.file.syntax == Syntax.Proto2:
        result = true
    else:
        if isMapEntry(field):
            result = false
        elif isMessage(field):
            result = true
        elif field.oneof != nil:
            result = true

proc newField(file: ProtoFile, message: Message, desc: google_protobuf_FieldDescriptorProto): Field =
    new(result)

    result.name = toCamelCase(desc.name)
    result.protoName = desc.name
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
            yield indent(&"{message.names}_{oneof.name}_Kind* {{.pure.}} = enum", 0)
            for field in oneof.fields:
                yield indent(&"{field.name.capitalizeAscii}", 4)
            yield indent(&"NotSet", 4)
            yield ""
            yield &"{message.names}_{oneof.name}_OneOf* = object"
            yield indent(&"case kind*: {message.names}_{oneof.name}_Kind", 4)
            for field in oneof.fields:
                yield indent(&"of {message.names}_{oneof.name}_Kind.{field.name.capitalizeAscii}: {quoteReserved(field.name)}*: {field.fullType}", 4)
            yield indent(&"of {message.names}_{oneof.name}_Kind.NotSet: nil", 4)

iterator genNewMessageProc(msg: Message): string =
    yield &"proc new{msg.names}*(): {msg.names} ="
    yield indent("new(result)", 4)
    yield indent("initMessage(result[])", 4)
    yield indent(&"result.procs = {msg.names}Procs()", 4)
    for field in msg.fields:
        if field.oneof == nil:
            yield indent(&"result.{field.accessor} = {defaultValue(field)}", 4)
    for oneof in msg.oneofs:
        yield indent(&"result.{oneof.name}.kind = {msg.names}_{oneof.name}_Kind.NotSet", 4)
    yield ""

iterator oneofSiblings(field: Field): Field =
    if field.oneof != nil:
        for sibling in field.oneof.fields:
            if sibling == field:
                continue
            yield sibling

iterator genClearFieldProc(msg: Message, field: Field): string =
    yield &"proc clear{field.name}*(message: {msg.names}) ="
    if field.oneof == nil:
        yield indent(&"message.{field.accessor} = {defaultValue(field)}", 4)
    else:
        let oneof = field.oneof
        yield indent(&"reset(message.{oneof.name})", 4)
        yield indent(&"message.{oneof.name}.kind = {msg.names}_{oneof.name}_Kind.NotSet", 4)
    if shouldGenerateHasField(msg, field):
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
    if field.oneof == nil:
        yield indent(&"message.{field.accessor} = value", 4)
    else:
        yield indent(&"if message.{field.oneof.name}.kind != {msg.names}_{field.oneof.name}_Kind.{field.name.capitalizeAscii}:", 4)
        yield indent(&"reset(message.{field.oneof.name})", 8)
        yield indent(&"message.{field.oneof.name}.kind = {msg.names}_{field.oneof.name}_Kind.{field.name.capitalizeAscii}", 8)
        yield indent(&"message.{field.accessor} = value", 4)
    if shouldGenerateHasField(msg, field):
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

proc hasFieldCheck(msg: string, field: Field): string =
    if isRepeated(field) or isMapEntry(field):
        return &"len({msg}.{field.accessor}) > 0"
    elif field.message.file.syntax == Syntax.Proto2:
        return &"has{field.name}({msg})"
    elif field.oneof != nil:
        # Oneof fields only check the kind of the oneof field. If we anded this
        # check with a check from below, we couldn't convey to the deserializing
        # side which oneof field was set. For example, if we are serializing an
        # string, if we included the string check, we wouldn't serialize
        # anything. This would make the receiving end think that the oneof field
        # didn't have anything set even though on the sending side the string
        # field was actually set. So by also serializing the default values on
        # the wire, we give some information about the oneof field itself.
        return &"{msg}.{field.oneof.name}.kind == {field.message.names}_{field.oneof.name}_Kind.{field.name.capitalizeAscii}"

    case field.ftype
    of google_protobuf_FieldDescriptorProtoType.TypeDouble,
       google_protobuf_FieldDescriptorProtoType.TypeFloat,
       google_protobuf_FieldDescriptorProtoType.TypeInt64,
       google_protobuf_FieldDescriptorProtoType.TypeUInt64,
       google_protobuf_FieldDescriptorProtoType.TypeInt32,
       google_protobuf_FieldDescriptorProtoType.TypeFixed64,
       google_protobuf_FieldDescriptorProtoType.TypeFixed32,
       google_protobuf_FieldDescriptorProtoType.TypeUInt32,
       google_protobuf_FieldDescriptorProtoType.TypeSFixed32,
       google_protobuf_FieldDescriptorProtoType.TypeSFixed64,
       google_protobuf_FieldDescriptorProtoType.TypeSInt32,
       google_protobuf_FieldDescriptorProtoType.TypeSInt64,
       google_protobuf_FieldDescriptorProtoType.TypeBool,
       google_protobuf_FieldDescriptorProtoType.TypeEnum:
        result = &"{msg}.{field.accessor} != {defaultValue(field)}"
    of google_protobuf_FieldDescriptorProtoType.TypeString,
       google_protobuf_FieldDescriptorProtoType.TypeBytes:
        result = &"len({msg}.{field.accessor}) > 0"
    of google_protobuf_FieldDescriptorProtoType.TypeGroup: result = ""
    of google_protobuf_FieldDescriptorProtoType.TypeMessage:
        result = &"has{field.name}({msg})"

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
                let check = hasFieldCheck("message", field)
                yield indent(&"if {check}:", 4)
                yield indent(&"writeTag(stream, {field.number}, WireType.LengthDelimited)", 8)
                yield indent(&"writeVarint(stream, packedFieldSize(message.{field.name}, {field.fieldTypeStr}))", 8)
                yield indent(&"for value in message.{field.name}:", 8)
                yield indent(&"{field.writeProc}(stream, value)", 12)
            else:
                yield indent(&"for value in message.{field.name}:", 4)
                yield indent(&"{field.writeProc}(stream, value, {field.number})", 8)
        else:
            let check = hasFieldCheck("message", field)
            yield indent(&"if {check}:", 4)
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
        let check = hasFieldCheck("message", field)
        if isMapEntry(field):
            yield indent(&"if {check}:", 4)
            yield indent(&"var sizeOfKV = 0'u64", 8)
            yield indent(&"for key, value in message.{field.name}:", 8)
            yield indent(&"sizeOfKV = sizeOfKV + {field.sizeOfProc}(key, value)", 12)
            yield indent(&"result = result + sizeOfTag({field.number}, {field.wiretypeStr})", 8)
            yield indent(&"result = result + sizeOfLengthDelimited(sizeOfKV)", 8)
        elif isRepeated(field):
            if isNumeric(field):
                yield indent(&"if {check}:", 4)
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
            yield indent(&"if {check}:", 4)
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
           google_protobuf_FieldDescriptorProto_Type.TypeFloat,
           google_protobuf_FieldDescriptorProto_Type.TypeEnum:
            result = &"toJson({v})"
        else:
            result = &"%{v}"

    for field in msg.fields:
        let check = hasFieldCheck("message", field)
        yield indent(&"if {check}:", 4)
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

iterator genMessageFromJsonProc(msg: Message): string =
    yield &"proc parse{msg.names}*(obj: JsonNode): {msg.names} ="
    yield indent(&"result = new{msg.names}()", 4)
    yield indent(&"var node: JsonNode", 4)

    yield indent("if obj.kind != JObject:", 4)
    yield indent("raise newException(nimpb_json.ParseError, \"object expected\")", 8)

    proc fieldFromJson(field: Field, n: string): string =
        if isMessage(field):
            result = &"parse{field.typeName}({n})"
        elif isEnum(field):
            result = &"parseEnum[{field.typeName}]({n})"
        elif isFloat(field):
            result = &"parseFloat[{field.nimTypeName}]({n})"
        elif field.ftype == google_protobuf_FieldDescriptorProto_Type.TypeBool:
            result = &"parseBool({n})"
        elif isNumeric(field):
            result = &"parseInt[{field.nimTypeName}]({n})"
        elif field.ftype == google_protobuf_FieldDescriptorProto_Type.TypeString:
            result = &"parseString({n})"
        elif field.ftype == google_protobuf_FieldDescriptorProto_Type.TypeBytes:
            result = &"parseBytes({n})"

    for field in msg.fields:
        yield indent(&"node = getJsonField(obj, \"{field.protoName}\", \"{field.jsonName}\")", 4)
        yield indent(&"if node != nil and node.kind != JNull:", 4)
        if field.oneof != nil:
            yield indent(&"if result.{field.oneof.name}.kind != {field.message.names}_{field.oneof.name}_Kind.NotSet:", 8)
            yield indent(&"raise newException(nimpb_json.ParseError, \"multiple values for oneof encountered\")", 12)
        if isMapEntry(field):
            yield indent("if node.kind != JObject:", 8)
            yield indent("raise newException(ValueError, \"not an object\")", 12)
            yield indent("for keyString, valueNode in node:", 8)
            let keyField = mapKeyField(field)
            if isBool(keyField):
                yield indent("let key = parseBool(keyString)", 12)
            elif isUnsigned(keyField):
                yield indent(&"let key = {keyField.nimTypeName}(parseBiggestUInt(keyString))", 12)
            elif isNumeric(keyField):
                yield indent(&"let key = {keyField.nimTypeName}(parseBiggestInt(keyString))", 12)
            elif keyField.ftype == google_protobuf_FieldDescriptorProto_Type.TypeString:
                yield indent("let key = keyString", 12)
            let valueField = mapValueField(field)
            let parser = fieldFromJson(valueField, "valueNode")
            yield indent(&"result.{field.name}[key] = {parser}", 12)
        elif isRepeated(field):
            let parser = fieldFromJson(field, "value")
            yield indent("if node.kind != JArray:", 8)
            yield indent("raise newException(ValueError, \"not an array\")", 12)
            yield indent("for value in node:", 8)
            yield indent(&"add{field.name}(result, {parser})", 12)
        else:
            let parser = fieldFromJson(field, "node")
            yield indent(&"set{field.name}(result, {parser})", 8)

    yield ""

iterator genMessageProcForwards(msg: Message): string =
    # TODO: can we be more intelligent and only forward declare the minimum set
    # of procs?
    if not isMapEntry(msg):
        yield &"proc new{msg.names}*(): {msg.names}"
        yield &"proc new{msg.names}*(data: string): {msg.names}"
        yield &"proc new{msg.names}*(data: seq[byte]): {msg.names}"
        yield &"proc write{msg.names}*(stream: Stream, message: {msg.names})"
        yield &"proc read{msg.names}*(stream: Stream): {msg.names}"
        yield &"proc sizeOf{msg.names}*(message: {msg.names}): uint64"
        if msg.file.syntax == Syntax.Proto3 and shouldGenerateJsonProcs($msg.names):
            yield &"proc toJson*(message: {msg.names}): JsonNode"
            yield &"proc parse{msg.names}*(obj: JsonNode): {msg.names}"
    else:
        let
            key = mapKeyField(msg)
            value = mapValueField(msg)

        yield &"proc write{msg.names}KV(stream: Stream, key: {key.fullType}, value: {value.fullType})"
        yield &"proc read{msg.names}KV(stream: Stream, tbl: TableRef[{key.fullType}, {value.fullType}])"
        yield &"proc sizeOf{msg.names}KV(key: {key.fullType}, value: {value.fullType}): uint64"

iterator genMessageProcImpls(msg: Message): string =
    yield &"proc read{msg.names}Impl(stream: Stream): Message = read{msg.names}(stream)"
    yield &"proc write{msg.names}Impl(stream: Stream, msg: Message) = write{msg.names}(stream, {msg.names}(msg))"
    if msg.file.syntax == Syntax.Proto3 and shouldGenerateJsonProcs($msg.names):
        yield &"proc toJson{msg.names}Impl(msg: Message): JsonNode = toJson({msg.names}(msg))"
        yield &"proc fromJson{msg.names}Impl(node: JsonNode): Message = parse{msg.names}(node)"
    yield ""
    yield &"proc {msg.names}Procs*(): MessageProcs ="
    yield &"    result.readImpl = read{msg.names}Impl"
    yield &"    result.writeImpl = write{msg.names}Impl"
    if msg.file.syntax == Syntax.Proto3 and shouldGenerateJsonProcs($msg.names):
        yield &"    result.toJsonImpl = toJson{msg.names}Impl"
        yield &"    result.fromJsonImpl = fromJson{msg.names}Impl"
    yield ""

iterator genProcs(msg: Message): string =
    if isMapEntry(msg):
        for line in genSizeOfMapKVProc(msg): yield line
        for line in genWriteMapKVProc(msg): yield line
        for line in genReadMapKVProc(msg): yield line
    else:
        yield &"proc fullyQualifiedName*(T: typedesc[{msg.names}]): string = \"{join(seq[string](msg.names), \".\")}\""
        yield ""

        for line in genMessageProcImpls(msg): yield line

        for line in genNewMessageProc(msg): yield line

        for field in msg.fields:
            for line in genClearFieldProc(msg, field): yield line
            if shouldGenerateHasField(msg, field):
                for line in genHasFieldProc(msg, field): yield line
            for line in genSetFieldProc(msg, field): yield line

            if isRepeated(field) and not isMapEntry(field):
                for line in genAddToFieldProc(msg, field): yield line

            for line in genFieldAccessorProcs(msg, field): yield line

        for line in genSizeOfMessageProc(msg): yield line
        for line in genWriteMessageProc(msg): yield line
        for line in genReadMessageProc(msg): yield line

        if msg.file.syntax == Syntax.Proto3 and shouldGenerateJsonProcs($msg.names):
            for line in genMessageToJsonProc(msg): yield line
            for line in genMessageFromJsonProc(msg): yield line

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

        yield &"proc new{msg.names}*(data: seq[byte]): {msg.names} ="
        yield indent("let", 4)
        yield indent("ss = newStringStream(cast[string](data))", 8)
        yield indent(&"result = read{msg.names}(ss)", 4)
        yield ""

proc hasGenImports(serviceGenerator: ServiceGenerator): bool =
    serviceGenerator != nil and serviceGenerator.genImports != nil

proc hasGenService(serviceGenerator: ServiceGenerator): bool =
    serviceGenerator != nil and serviceGenerator.genService != nil

proc ownFile(serviceGenerator: ServiceGenerator): bool =
    serviceGenerator != nil and serviceGenerator.fileSuffix != nil

proc processFile(fdesc: google_protobuf_FileDescriptorProto,
                 otherFiles: TableRef[string, ProtoFile],
                 serviceGenerator: ServiceGenerator): seq[ProcessedFile] =
    result = @[]

    var (dir, name, _) = splitFile(fdesc.name)
    var pbfilename = (dir / name) & "_pb.nim"

    log(&"processing {fdesc.name}: {pbfilename}")

    var pbFile = ProcessedFile(name: pbfilename, data: "")
    var serviceFile = pbFile

    add(result, pbFile)

    if serviceGenerator != nil:
        serviceGenerator.fileName = name & "_pb"

    if ownFile(serviceGenerator):
        var serviceFilename = (dir / name) & "_" & serviceGenerator.fileSuffix & ".nim"
        serviceFile = ProcessedFile(name: serviceFilename, data: "")
        add(result, serviceFile)

    let parsed = parseFile(fdesc.name, fdesc)

    for dep in fdesc.dependency:
        if dep in otherFiles:
            add(parsed.dependencies, otherFiles[dep])

    var hasMaps = false
    for message in parsed.messages:
        let tmp = fixMapEntry(parsed, message)
        if tmp:
            hasMaps = true

    addLine(pbFile.data, "# Generated by protoc_gen_nim. Do not edit!")
    addLine(pbFile.data, "")
    addLine(pbFile.data, "import base64")
    addLine(pbFile.data, "import intsets")
    addLine(pbFile.data, "import json")
    addLine(pbFile.data, "import strutils")
    if hasMaps:
        addLine(pbFile.data, "import tables")
        addLine(pbFile.data, "export tables")
    addLine(pbFile.data, "")
    addLine(pbFile.data, "import nimpb/nimpb")
    addLine(pbFile.data, "import nimpb/json as nimpb_json")
    addLine(pbFile.data, "")

    if hasGenImports(serviceGenerator):
        add(serviceFile.data, serviceGenerator.genImports())

    # if serviceGenerator != nil:
    #     if serviceGenerator.genImports != nil:
    #         add(pbFile.data, serviceGenerator.genImports())

    for dep in fdesc.dependency:
        var (dir, depname, _) = splitFile(dep)

        if dir == "google/protobuf":
            dir = "nimpb/wkt"
            if depname notin WktsWithExtras:
                depname &= "_pb"
        else:
            depname &= "_pb"

        addLine(pbFile.data, &"import {dir / depname}")

    if hasDependency(fdesc):
        addLine(pbFile.data, "")

    addLine(pbFile.data, "type")

    for e in parsed.enums:
        for line in genType(e): addLine(pbFile.data, indent(line, 4))

    for message in parsed.messages:
        for line in genType(message): addLine(pbFile.data, indent(line, 4))

    addLine(pbFile.data, "")

    for message in sortDependencies(parsed.messages):
        for line in genMessageProcForwards(message):
            addLine(pbFile.data, line)
        addLine(pbFile.data, "")

    for message in sortDependencies(parsed.messages):
        for line in genProcs(message):
            addLine(pbFile.data, line)
        addLine(pbFile.data, "")

    if hasGenService(serviceGenerator):
        for serviceDesc in fdesc.service:
            let service = newService(serviceDesc, parsed)
            add(serviceFile.data, serviceGenerator.genService(service))

proc processFileDescriptorSet*(filename: string,
                               outdir: string,
                               protos: openArray[string],
                               serviceGenerator: ServiceGenerator) =
    ## Generate code from a FileDescriptorSet stored in a file.
    ##
    ## ``filename`` is the full path to the file storing the FileDescriptorSet.
    ## ``outdir`` is the output directory for files. ``protos`` contains the
    ## paths to the proto files which were passed to the protoc compiler.
    ## ``serviceGenerator`` specifies the user supplied service generator.
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
            for processedFile in processFile(file, otherFiles, serviceGenerator):
                let fullPath = outdir / processedFile.name
                createDir(parentDir(fullPath))
                writeFile(fullPath, processedFile.data)
