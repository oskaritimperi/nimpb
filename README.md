# Protocol Buffers for Nim

A Nim library to serialize/deserialize Protocol Buffers.

To actually generate Nim code from protobuf definitions, you need the protoc
tool. To make things simple, nimpb depends on
[nimpb_protoc](https://github.com/oswjk/nimpb_protoc), which bundles protoc
binaries for the most common platforms (Windows, Linux, macOS).

**NOTE** At the moment this is at a very rough state. Do not use for any kind of production use. Anything can change at any time. You've been warned.

# Example

Given the following file:

```
syntax = "proto3";

message Test1 {
    int32 a = 1;

    enum MyEnum {
        Foo = 0;
        Bar = 1;
    }

    MyEnum e = 2;
}
```

You can use nimpb_build (a tool that comes with nimpb) to generate code like this (procs not included in the example):

```nim
type
    Test1_MyEnum* {.pure.} = enum
        Foo = 0
        Bar = 1

    Test1* = ref Test1Obj
    Test1Obj* = object of RootObj
        a: int32
        e: MyEnum
```

And you can use the generated code like this:

```nim
let message = newTest1()
message.a = 150
message.e = Test1_MyEnum.Bar

let data = serialize(message)

let message2 = newTest1(data)

assert message2.a == 150
assert message2.e == Test1_MyEnum.Bar
```

# Other libraries

If you do not want to depend on the `protoc` compiler, check Peter Munch-Ellingsen's [protobuf library](https://github.com/PMunch/protobuf-nim). It handles parsing of the protobuf files in compile time which can make building simpler.
