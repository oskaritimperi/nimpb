PLUGIN = ../../generator/protoc_gen_nim

all: writer reader

writer: writer.nim addressbook_pb.nim
	nim c writer.nim

reader: reader.nim addressbook_pb.nim
	nim c reader.nim

addressbook_pb.nim: addressbook.proto
	protoc --plugin=protoc-gen-nim=$(PLUGIN) --nim_out=. -I. addressbook.proto
