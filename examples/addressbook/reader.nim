import streams
import strformat

import nimpb/nimpb

import addressbook_pb
import phonenumber_pb

let pbsi = newFileStream("addressbook.dat")

let addressBook = readAddressBook(pbsi)

for person in addressBook.people:
    echo("---")
    echo(&"Id: {person.id}")
    echo(&"Name: {person.name}")
    echo(&"Email: {person.email}")
    echo("Phones:")
    for phone in person.phones:
        echo(&"  {phone.ftype} {phone.number}")
