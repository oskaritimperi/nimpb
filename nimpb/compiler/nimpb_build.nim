import os
import osproc
import parseopt2
import strformat
import strutils

import compiler

proc usage() {.noreturn.} =
    echo(&"""
{getAppFilename()} --out=OUTDIR [-I=PATH [-I=PATH]...] PROTOFILE...

    --out       The output directory for the generated files
    -I          Add a path to the set of include paths
""")
    quit(QuitFailure)

var includes: seq[string] = @[]
var protos: seq[string] = @[]
var outdir: string

for kind, key, val in getopt():
    case kind
    of cmdArgument:
        add(protos, key)
    of cmdLongOption, cmdShortOption:
        case key
        of "help", "h": usage()
        of "out": outdir = val
        of "I": add(includes, val)
        else:
            echo("error: unknown option: " & key)
            usage()
    of cmdEnd: assert(false)

if outdir == nil:
    echo("error: --out is required")
    quit(QuitFailure)

if len(protos) == 0:
    echo("error: no input files")
    quit(QuitFailure)

compileProtos(protos, includes, outdir)
