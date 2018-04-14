import macros
import os
import osproc
import strformat
import strutils

from generator import processFileDescriptorSet, ServiceGenerator, Service, ServiceMethod
export ServiceGenerator, Service, ServiceMethod

const
    nimpbProtocInfo = gorgeEx("nimble dump nimpb_protoc")
    isNimpbProtocAvailable = nimpbProtocInfo[1] == 0

when isNimpbProtocAvailable:
    import nimpb_protoc

proc findCompiler*(): string =
    result = ""

    if existsEnv("NIMPB_PROTOC"):
        result = getEnv("NIMPB_PROTOC")
        if not fileExists(result):
            result = ""

    if result == "":
        result = findExe("protoc")

    when isNimpbProtocAvailable:
        if result == "":
            result = nimpb_protoc.getCompilerPath()

    if result == "":
        let msg = """
error: protoc compiler not found

Now you have three options to make this work:

1. Tell me the full path to the protoc executable by using NIMPB_PROTOC
   environment variable

2. You can also make sure that protoc is in PATH, which will make me find it

3. Install nimpb_protoc with nimble, which includes the protoc compiler for the
   most common platforms (Windows, Linux, macOS) and I should be able to pick
   it up after a recompile

"""

        raise newException(Exception, msg)

proc myTempDir(): string =
    result = getTempDir() / "nimpb_protoc_tmp"

proc compileProtos*(protos: openArray[string],
                    includes: openArray[string],
                    outdir: string,
                    serviceGenerator: ServiceGenerator = nil) =
    let command = findCompiler()
    var args: seq[string] = @[]

    var outputFilename = myTempDir() / "file-descriptor-set"
    createDir(myTempDir())

    add(args, "--include_imports")
    add(args, "--include_source_info")
    add(args, &"-o{outputFilename}")

    for incdir in includes:
        add(args, &"-I{incdir}")

    when isNimpbProtocAvailable:
        add(args, &"-I{getProtoIncludeDir()}")

    for proto in protos:
        add(args, proto)

    var cmdline: string = quoteShell(command)
    for arg in args:
        cmdline &= " " & quoteShell(arg)

    let (outp, rc) = execCmdEx(cmdline)

    if rc != 0:
        raise newException(Exception, outp)

    processFileDescriptorSet(outputFilename, outdir, protos, serviceGenerator)
