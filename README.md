# Protocol Buffers for Nim

A pure Nim library for dealing with protobuf serialization and deserialization. A `protoc` plugin is also included which can be used for generating Nim code, usable by the library, from `.proto` files.

At the moment this is at a very rough state. Do not use for any kind of production use.

# Example

Given the following file:

```
syntax = "proto3";

message Test1 {
    int32 a = 1;
}
```

The `protoc` plugin will basically generate the following code:

```nim
const
    Test1Desc = MessageDesc(
        name: "Test1",
        fields: @[
            FieldDesc(
                name: "a",
                number: 1,
                ftype: FieldType.Int32,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false
            )
        ]
    )

generateMessageType(Test1Desc)
generateMessageProcs(Test1Desc)
```

And you can use it like this:

```
let message = newTest1()
setA(message, 150)
let pbso = newProtobufStream(newFileStream(stdout))
writeTest1(pbso, message)
```
