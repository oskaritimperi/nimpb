PLUGIN = ../../generator/protoc_gen_nim

all: simple

simple: simple.nim simple_pb.nim
	nim c simple.nim

simple_pb.nim: simple.proto
	protoc --plugin=protoc-gen-nim=$(PLUGIN) --nim_out=. -I. simple.proto
