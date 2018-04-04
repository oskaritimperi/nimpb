# protoc_gen_nim

A protoc plugin for generating Nim code out of .proto files.

# Usage

If you don't have the directory, where the generator plugin resides, in PATH, you can use

    protoc --plugin=protoc-gen-nim=/path/to/protoc_gen_nim --nim_out=protos -I. my.proto

If the plugin is in PATH (and you're on a unix-ish system) then it's a bit easier

    protoc -I. --nim_out=protos my.proto

The latter style is possible, because there exists a `protoc-gen-nim` wrapper script that calls the real executable. Protoc automatically finds this wrapper based on the `--nim_out` argument.
