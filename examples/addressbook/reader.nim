import streams
import strformat

import protobuf/stream

import addressbook_pb

let pbsi = newProtobufStream(newFileStream("addressbook.dat"))

let addressBook = readAddressBook(pbsi)

for person in addressBook.people:
    echo("---")
    echo(&"Id: {person.id}")
    echo(&"Name: {person.name}")
    echo(&"Email: {person.email}")
    echo("Phones:")
    for phone in person.phones:
        echo(&"  {phone.type} {phone.number}")
