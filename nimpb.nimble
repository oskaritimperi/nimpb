version = "0.1.0"
author = "Oskari Timperi"
description = "protobuf library for Nim"
license = "MIT"

skipDirs = @["examples", "tests"]

bin = @["nimpb/compiler/nimpb_build"]

requires "nim >= 0.18.0"

# Hard dependency for now. In the future we could make nimpb_protoc download
# stuff on-demand which would make the dependency a bit lighter. Especially
# if a user already has the protoc compiler somewhere, in which case
# nimpb_protoc might be unnecessary.
requires "nimpb_protoc"
