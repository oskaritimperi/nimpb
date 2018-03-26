import streams

import protobuf/stream

import addressbook_pb

let addressBook = newAddressBook()

let john = newPerson()
setName(john, "John Doe")
setId(john, 1)
setEmail(john, "john.doe@example.com")
addPeople(addressBook, john)

let johnPhone1 = newPerson_PhoneNumber()
setNumber(johnPhone1, "1234")
setType(johnPhone1, MOBILE)
addPhones(john, johnPhone1)

let johnPhone2 = newPerson_PhoneNumber()
setNumber(johnPhone2, "5566")
setType(johnPhone2, WORK)
addPhones(john, johnPhone2)

let jane = newPerson()
setName(jane, "Jane Doe")
setId(jane, 2)
setEmail(jane, "jane.doe@example.com")
addPeople(addressBook, jane)

let janePhone1 = newPerson_PhoneNumber()
setNumber(janePhone1, "1432")
setType(janePhone1, HOME)
addPhones(jane, janePhone1)

let pbso = newProtobufStream(newFileStream("addressbook.dat", fmWrite))
writeAddressBook(pbso, addressBook)
