import simple_pb

let message = newTest1()
message.a = 150
message.e = Test1_MyEnum.Bar

let data = serialize(message)

let message2 = newTest1(data)

assert message2.a == 150
assert message2.e == Test1_MyEnum.Bar
