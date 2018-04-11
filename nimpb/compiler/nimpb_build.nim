import os
import osproc
import strformat
import strutils

import compiler

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
