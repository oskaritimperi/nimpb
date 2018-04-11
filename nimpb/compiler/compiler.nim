import macros
import os
import osproc
import strformat
import strutils

from generator import processFileDescriptorSet, ServiceGenerator, Service, ServiceMethod
export Service, ServiceMethod

const
    nimpbBuildInfo = gorgeEx("nimble dump nimpb_protoc")
    isNimpbBuildAvailable = nimpbBuildInfo[1] == 0

when isNimpbBuildAvailable:
    import nimpb_protoc/nimpb_protoc

proc findCompiler*(): string =
    result = ""

    if existsEnv("NIMPB_PROTOC"):
        result = getEnv("NIMPB_PROTOC")
        if not fileExists(result):
            result = ""

    if result == "":
        result = findExe("protoc")

    when isNimpbBuildAvailable:
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

proc builtinIncludeDir(compilerPath: string): string =
    parentDir(compilerPath) / "include"

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

    add(args, &"-I{builtinIncludeDir(command)}")

    for proto in protos:
        add(args, proto)

    var cmdline: string = quoteShell(command)
    for arg in args:
        cmdline &= " " & quoteShell(arg)

    let (outp, rc) = execCmdEx(cmdline)

    if rc != 0:
        raise newException(Exception, outp)

    processFileDescriptorSet(outputFilename, outdir, protos, serviceGenerator)


when isMainModule:
    proc usage() {.noreturn.} =
        echo(&"""
    {getAppFilename()} --out=OUTDIR [-IPATH [-IPATH]...] PROTOFILE...

        --out       The output directory for the generated files
        -I          Add a path to the set of include paths
    """)
        quit(QuitFailure)

    var includes: seq[string] = @[]
    var protos: seq[string] = @[]
    var outdir: string

    if paramCount() == 0:
        usage()

    for idx in 1..paramCount():
        let param = paramStr(idx)

        if param.startsWith("-I"):
            add(includes, param[2..^1])
        elif param.startsWith("--out="):
            outdir = param[6..^1]
        elif param == "--help":
            usage()
        else:
            add(protos, param)

    if outdir == nil:
        echo("error: --out is required")
        quit(QuitFailure)

    if len(protos) == 0:
        echo("error: no input files")
        quit(QuitFailure)

    compileProtos(protos, includes, outdir)
