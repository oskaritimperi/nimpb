import streams

import protobuf/stream

import addressbook_pb
import phonenumber_pb

let addressBook = newAddressBook()

let john = newPerson()
john.name = "John Doe"
john.id = 1
john.email = "john.doe@example.com"
addPeople(addressBook, john)

let johnPhone1 = newPhoneNumber()
johnPhone1.number = "1234"
johnPhone1.ftype = PhoneType.MOBILE
addPhones(john, johnPhone1)

let johnPhone2 = newPhoneNumber()
setNumber(johnPhone2, "5566")
setFType(johnPhone2, WORK)
addPhones(john, johnPhone2)

let jane = newPerson()
setName(jane, "Jane Doe")
setId(jane, 2)
setEmail(jane, "jane.doe@example.com")
addPeople(addressBook, jane)

let janePhone1 = newPhoneNumber()
setNumber(janePhone1, "1432")
setFType(janePhone1, HOME)
addPhones(jane, janePhone1)

let pbso = newProtobufStream(newFileStream("addressbook.dat", fmWrite))
writeAddressBook(pbso, addressBook)
