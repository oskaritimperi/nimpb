import intsets

import protobuf/types
import protobuf/gen
import protobuf/stream

const
    Test1Desc = MessageDesc(
        name: "Test1",
        fields: @[
            FieldDesc(
                name: "a",
                number: 1,
                ftype: FieldType.Int32,
                label: FieldLabel.Required,
                typeName: "",
                packed: true
            )
        ]
    )

    Test3Desc = MessageDesc(
        name: "Test3",
        fields: @[
            FieldDesc(
                name: "c",
                number: 3,
                ftype: FieldType.Message,
                label: FieldLabel.Required,
                typeName: "Test1",
                packed: false
            )
        ]
    )

generateMessageType(Test1Desc)
generateMessageProcs(Test1Desc)

generateMessageType(Test3Desc)
generateMessageProcs(Test3Desc)

import strutils
let message = newTest3()
let t1 = newTest1()
setA(t1, 150)
setC(message, t1)
let ss = newStringStream()
let pbs = newProtobufStream(ss)
writeTest3(pbs, message)
for b in ss.data:
    echo(toHex(int(b), 2))

setPosition(pbs, 0)
let message2 = readTest3(pbs)
echo(message2.c.a)
