import os
import osproc
import streams
import strformat
import strtabs
import strutils

from plugin import processFileDescriptorSet, ServiceGenerator, Service, ServiceMethod

export Service, ServiceMethod

when defined(windows):
    const compilerId = "win32"
elif defined(linux):
    when defined(i386):
        const arch = "x86_32"
    elif defined(amd64):
        const arch = "x86_64"
    elif defined(arm64):
        const arch = "aarch_64"
    else:
        {.fatal:"unsupported architecture".}
    const compilerId = "linux-" & arch
elif defined(macosx):
    when defined(amd64):
        const arch = "x86_64"
    else:
        {.fatal:"unsupported architecture".}
    const compilerId = "osx-" & arch
else:
    {.fatal:"unsupported platform".}

when defined(windows):
    const exeSuffix = ".exe"
else:
    const exeSuffix = ""

proc findCompiler(): string =
    let
        compilerName = &"protoc-{compilerId}{exeSuffix}"
        paths = @[
            getAppDir() / "src" / "nimpb_buildpkg" / "protobuf",
            getAppDir() / "nimpb_buildpkg" / "protobuf",
            parentDir(currentSourcePath()) / "nimpb_buildpkg" / "protobuf",
        ]

    for path in paths:
        if fileExists(path / compilerName):
            return path / compilerName

    raise newException(Exception, &"{compilerName} not found!")

proc builtinIncludeDir(compilerPath: string): string =
    parentDir(compilerPath) / "include"

template verboseEcho(x: untyped): untyped =
    if verbose:
        echo(x)

proc myTempDir(): string =
    result = getTempDir() / "nimpb_build_tmp"

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
