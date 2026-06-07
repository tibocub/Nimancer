import std/[os]
from std/algorithm import reverse

import ./types
import ./parse_argv
import ./help

proc parse*(prog: Command; argv: seq[string]): ParseResult =
  ## Parses argv into a `ParseResult` without invoking any actions.
  parseArgv(prog, argv)

proc commandPath(cmd: Command): seq[string] =
  var cur = cmd
  while cur != nil and cur.parent != nil:
    result.add cur.name
    cur = cur.parent
  result.reverse()

proc run*(prog: Command; argv: seq[string] = commandLineParams()): int =
  ## Parses argv, handles help/error output, and dispatches the matched command action.
  let parsed = parseArgv(prog, argv)

  if parsed.error.len > 0:
    if not parsed.command.silenceErrors:
      stderr.writeLine "Error: " & parsed.error

    if not parsed.command.silenceUsage:
      let path = commandPath(parsed.command)
      stderr.writeLine renderHelp(HelpContext(cmd: parsed.command, path: path, progName: prog.name))

    return 1

  if parsed.helpRequested:
    let path = commandPath(parsed.command)
    stdout.writeLine renderHelp(HelpContext(cmd: parsed.command, path: path, progName: prog.name))
    return 0

  if parsed.command.name == "help":
    stdout.writeLine helpForPath(prog, parsed.ctx.args, prog.name)
    return 0

  if parsed.command.actionCb == nil:
    let path = commandPath(parsed.command)
    stdout.writeLine renderHelp(HelpContext(cmd: parsed.command, path: path, progName: prog.name))
    return 0

  if parsed.command.preRunCb != nil:
    parsed.command.preRunCb(parsed.ctx)

  result = parsed.command.actionCb(parsed.ctx)

  if parsed.command.postRunCb != nil:
    parsed.command.postRunCb(parsed.ctx)
