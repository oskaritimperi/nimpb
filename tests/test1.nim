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

generateMessageType(Test1Desc)
generateMessageProcs(Test1Desc)

import strutils
let message = newTest1()
setA(message, 150)
let ss = newStringStream()
let pbs = newProtobufStream(ss)
writeTest1(pbs, message)
for b in ss.data:
    echo(toHex(int(b), 2))

setPosition(pbs, 0)
let message2 = readTest1(pbs)
echo(message2.a)
