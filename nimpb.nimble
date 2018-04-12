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

import ospaths, strformat

task run_conformance_tests, "Run the conformance test suite":
    var testDir = "tests/conformance"
    var proto = testDir / "test_messages_proto3.proto"
    var testRunner = "../protobuf-3.5.1/conformance/conformance-test-runner"
    exec &"./nimpb/compiler/nimpb_build -I{testDir} --out={testDir} {proto}"
    exec &"./nimpb/compiler/nimpb_build -I{testDir} --out={testDir} {testDir}/conformance.proto"
    exec &"nimble c {testDir}/conformance_nim.nim"
    exec &"{testRunner} {testDir}/conformance_nim"

task gen_wkt, "Re-generate WKT's":
    var incdir = "../nimpb_protoc/src/nimpb_protocpkg/protobuf/include/google/protobuf"
    var outdir = "nimpb/wkt"
    for proto in listFiles(incdir):
        echo(&"COMPILING {proto}")
        exec &"./nimpb/compiler/nimpb_build -I{incdir} --out={outdir} {proto}"
