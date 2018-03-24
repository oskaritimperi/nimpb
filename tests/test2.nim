import intsets

import protobuf/types
import protobuf/gen
import protobuf/stream

const
    Test2Desc = MessageDesc(
        name: "Test2",
        fields: @[
            FieldDesc(
                name: "b",
                number: 2,
                ftype: FieldType.String,
                label: FieldLabel.Required,
                typeName: "",
                packed: false
            )
        ]
    )

generateMessageType(Test2Desc)
generateMessageProcs(Test2Desc)

import strutils
let message = newTest2()
setB(message, "testing")
let ss = newStringStream()
let pbs = newProtobufStream(ss)
writeTest2(pbs, message)
for b in ss.data:
    echo(toHex(int(b), 2))

setPosition(pbs, 0)
let message2 = readTest2(pbs)
echo(message2.b)
