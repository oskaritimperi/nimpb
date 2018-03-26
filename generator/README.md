# protoc_gen_nim

A protoc plugin for generating Nim code out of .proto files.

# Usage

    protoc --plugin=protoc-gen-nim=./protoc_gen_nim --nim_out=protos -I. my.proto
