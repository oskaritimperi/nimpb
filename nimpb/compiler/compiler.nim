## This module implements functionality for finding and invoking the protoc
## compiler.

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
    ## Find the protoc compiler binary.
    ##
    ## This proc tries to find the protoc executable. The locations in order of
    ## trying are:
    ##
    ## 1. If ``NIMPB_PROTOC`` environment variable is set, use it as the path to
    ##    protoc executable
    ## 2. Use ``os.findExe()`` to search for the executable
    ## 3. If `nimpb_protoc` nimble package is available, try to use the protoc
    ##    executable from it
    ##
    ## If the executable cannot be found, an exception is raised.
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
    # TODO: make this unique
    result = getTempDir() / "nimpb_protoc_tmp"

proc compileProtos*(protos: openArray[string],
                    includes: openArray[string],
                    outdir: string,
                    serviceGenerator: ServiceGenerator = nil) =
    ## Compile proto files to Nim code.
    ##
    ## This proc invokes the protoc compiler to do the actual job.
    ##
    ## Compiles the files passed in ``protos``, using include directories
    ## specified in ``includes``. Note that the include directories need to
    ## include the directories where the input files live. The generated files
    ## are written to ``outdir``.
    ##
    ## If ``serviceGenerator`` is not nil, it will be called for each defined
    ## service.
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
