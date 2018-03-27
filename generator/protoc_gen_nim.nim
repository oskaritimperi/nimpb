import algorithm
import os
import sequtils
import sets
import strformat
import strutils
import tables

import descriptor_pb
import plugin_pb

import protobuf/stream
import protobuf/types
import protobuf/gen

type
    Names = distinct seq[string]

    Enum = ref object
        names: Names
        values: seq[tuple[name: string, number: int]]

    Field = ref object
        number: int
        name: string
        label: FieldLabel
        ftype: FieldType
        typeName: string
        packed: bool
        oneofIdx: int

    Message = ref object
        names: Names
        fields: seq[Field]
        oneofs: seq[string]

    ProcessedFile = ref object
        name: string
        data: string

    ProtoFile = ref object
        fdesc: FileDescriptorProto
        enums: seq[Enum]
        messages: seq[Message]

when defined(debug):
    proc log(msg: string) =
        stderr.write(msg)
        stderr.write("\n")
else:
    proc log(msg: string) = discard

proc initNames(n: seq[string]): Names =
    result = Names(n)

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

proc add(names: var Names, other: Names) =
    names = Names(seq[string](names) & seq[string](other))

proc `&`(names: Names, s: string): Names =
    result = names
    add(result, s)

proc `==`(a, b: Names): bool =
    result = seq[string](a) == seq[string](b)

proc convertFieldType(t: FieldDescriptorProto_Type): FieldType =
    result = FieldType(int(t))

proc convertFieldLabel(t: FieldDescriptorProto_Label): FieldLabel =
    result = FieldLabel(int(t))

proc newField(desc: FieldDescriptorProto): Field =
    new(result)

    result.name = desc.name
    result.number = desc.number
    result.label = convertFieldLabel(desc.label)
    result.ftype = convertFieldType(desc.type)
    result.typeName = ""
    result.packed = desc.options.packed
    result.oneofIdx =
        if hasOneof_index(desc):
            desc.oneof_index
        else:
            -1

    if result.ftype == FieldType.Message or result.ftype == FieldType.Enum:
        result.typeName = $initNamesFromTypeName(desc.type_name)

    log(&"newField {result.name} {$result.ftype} {result.typeName}")

proc newMessage(names: Names, desc: DescriptorProto): Message =
    new(result)

    result.names = names
    result.fields = @[]
    result.oneofs = @[]

    log(&"newMessage {$result.names}")

    for field in desc.field:
        add(result.fields, newField(field))

    for oneof in desc.oneof_decl:
        add(result.oneofs, oneof.name)

proc newEnum(names: Names, desc: EnumDescriptorProto): Enum =
    new(result)

    result.names = names & desc.name
    result.values = @[]

    log(&"newEnum {$result.names}")

    for value in desc.value:
        add(result.values, (value.name, int(value.number)))

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

proc dependencies(field: Field): seq[string] =
    result = @[]

    if field.ftype == FieldType.Message or field.ftype == FieldType.Enum:
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
                    raise newException(Exception, "cycle detected")
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

    let basename: Names = Names(@[])

    for e in fdesc.enum_type:
        add(result.enums, newEnum(basename, e))

    for name, message in messages(fdesc, basename):
        add(result.messages, newMessage(name, message))

        for e in message.enum_type:
            add(result.enums, newEnum(name, e))

proc addLine(s: var string, line: string, indent: int = 0) =
    if indent > 0:
        s &= repeat(' ', indent)
    s &= line
    s &= "\n"

proc generateDesc(field: Field): string =
    result = ""
    addLine(result, "FieldDesc(", 12)
    addLine(result, &"name: \"{field.name}\",", 16)
    addLine(result, &"number: {field.number},", 16)
    addLine(result, &"ftype: FieldType.{field.ftype},", 16)
    addLine(result, &"label: FieldLabel.{field.label},", 16)
    addLine(result, &"typeName: \"{field.typeName}\",", 16)
    addLine(result, &"packed: {field.packed},", 16)
    addLine(result, &"oneofIdx: {field.oneofIdx},", 16)
    addLine(result, "),", 12)

proc generateDesc(message: Message): string =
    result = ""
    addLine(result, &"{message.names}Desc = MessageDesc(", 4)
    addLine(result, &"name: \"{message.names}\",", 8)
    addLine(result, "fields: @[", 8)
    for field in message.fields:
        result &= generateDesc(field)
    addLine(result, "],", 8)
    addLine(result, "oneofs: @[", 8)
    for oneof in message.oneofs:
        addLine(result, &"\"{oneof}\",", 12)
    addLine(result, "],", 8)
    addLine(result, ")", 4)

proc generateDesc(e: Enum): string =
    result = ""
    addLine(result, &"{e.names}Desc = EnumDesc(", 4)
    addLine(result, &"name: \"{e.names}\",", 8)
    addLine(result, "values: @[", 8)
    for v in e.values:
        addLine(result, &"EnumValueDesc(name: \"{v.name}\", number: {v.number}),", 12)
    addLine(result, "]", 8)
    addLine(result, ")", 4)

proc processFile(filename: string, fdesc: FileDescriptorProto,
                 otherFiles: TableRef[string, ProtoFile]): ProcessedFile =
    var (dir, name, _) = splitFile(filename)
    var pbfilename = (dir / name) & "_pb.nim"

    log(&"processing {filename}: {pbfilename}")

    new(result)
    result.name = pbfilename
    result.data = ""

    addLine(result.data, "# Generated by protoc_gen_nim. Do not edit!")
    addLine(result.data, "")
    addLine(result.data, "import intsets")
    addLine(result.data, "")
    addLine(result.data, "import protobuf/gen")
    addLine(result.data, "import protobuf/stream")
    addLine(result.data, "import protobuf/types")
    addLine(result.data, "")

    for dep in fdesc.dependency:
        var (dir, depname, _) = splitFile(dep)
        var deppbname = (dir / depname) & "_pb"
        addLine(result.data, &"import {deppbname}")

    if hasDependency(fdesc):
        addLine(result.data, "")

    let parsed = parseFile(filename, fdesc)

    addLine(result.data, "const")

    for e in parsed.enums:
        result.data &= generateDesc(e)

    for message in sortDependencies(parsed.messages):
        result.data &= generateDesc(message)

    for e in parsed.enums:
        addLine(result.data, &"generateEnumType({e.names}Desc)")
        addLine(result.data, &"generateEnumProcs({e.names}Desc)")

    for message in sortDependencies(parsed.messages):
        addLine(result.data, &"generateMessageType({message.names}Desc)")
        addLine(result.data, &"generateMessageProcs({message.names}Desc)")

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
