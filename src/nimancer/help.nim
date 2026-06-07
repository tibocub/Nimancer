import std/[strutils, sequtils]

import ./types

type
  HelpContext* = object ## Rendering inputs for command help and usage output.
    cmd*: Command
    path*: seq[string]
    progName*: string

proc hasRealSubcommands(cmd: Command): bool =
  for c in cmd.subcommands:
    if c.name != "help":
      return true
  false

proc argDisplay(spec: ArgSpec): string =
  if spec.required:
    return "<" & spec.name & ">"
  "[" & spec.name & "]"

proc commandLine(c: Command): string =
  let names = @[c.name] & c.aliases
  let args = c.arguments.mapIt(argDisplay(it))
  result = names.join(", ")
  if args.len > 0:
    result &= " " & args.join(" ")

proc optionLine(opt: OptionSpec): string =
  var parts: seq[string] = @[]

  if opt.shortFlag.len > 0:
    parts.add "-" & opt.shortFlag

  if opt.longFlag.len > 0:
    if opt.isNegatable:
      parts.add "--[no-]" & opt.longFlag
    else:
      parts.add "--" & opt.longFlag

  result = parts.join(", ")
  if not opt.isBool:
    if opt.valueName.len > 0:
      result &= " <" & opt.valueName & ">"
    else:
      result &= " <value>"

proc pathText(ctx: HelpContext): string =
  if ctx.path.len == 0:
    return ctx.progName
  ctx.progName & " " & ctx.path.join(" ")

proc buildUsageLine*(ctx: HelpContext): string =
  ## Builds a single-line usage synopsis for the selected command.
  result = pathText(ctx)

  if hasRealSubcommands(ctx.cmd):
    result &= " [command]"

  if ctx.cmd.options.len > 0:
    result &= " [options]"

  for a in ctx.cmd.arguments:
    result &= " " & argDisplay(a)

proc renderHelp*(ctx: HelpContext): string =
  ## Renders the full help text for a command.
  if ctx.cmd.helpRenderer != nil:
    return ctx.cmd.helpRenderer(ctx.cmd, ctx.path, ctx.progName)

  var sections: seq[string] = @[]
  sections.add "Usage: " & buildUsageLine(ctx)

  if ctx.cmd.description.len > 0:
    sections.add ctx.cmd.description

  let commands = ctx.cmd.subcommands.filterIt(it.name != "help")
  if commands.len > 0:
    var left: seq[string] = @[]
    for c in commands:
      left.add commandLine(c)

    let width = left.mapIt(it.len).foldl(max(a, b), 0)
    var lines: seq[string] = @["Commands:"]
    for idx, c in commands:
      let lhs = alignLeft(left[idx], width)
      var line = "  " & lhs
      if c.description.len > 0:
        line &= "  " & c.description
      lines.add line

    sections.add lines.join("\n")

  if ctx.cmd.arguments.len > 0:
    let left = ctx.cmd.arguments.mapIt(argDisplay(it))
    let width = left.mapIt(it.len).foldl(max(a, b), 0)
    var lines: seq[string] = @["Arguments:"]

    for idx, a in ctx.cmd.arguments:
      let lhs = alignLeft(left[idx], width)
      var line = "  " & lhs

      if a.description.len > 0:
        line &= "  " & a.description

      if a.defaultValue.len > 0:
        line &= " (default: " & a.defaultValue & ")"

      lines.add line

    sections.add lines.join("\n")

  if ctx.cmd.options.len > 0:
    let left = ctx.cmd.options.mapIt(optionLine(it))
    let width = left.mapIt(it.len).foldl(max(a, b), 0)
    var lines: seq[string] = @["Options:"]

    for idx, o in ctx.cmd.options:
      let lhs = alignLeft(left[idx], width)
      var line = "  " & lhs

      if o.description.len > 0:
        line &= "  " & o.description

      if (not o.isBool) and o.defaultValue.len > 0:
        line &= " (default: " & o.defaultValue & ")"

      lines.add line

    sections.add lines.join("\n")

  if commands.len > 0:
    let cmdPath = if ctx.path.len > 0: ctx.path.join(" ") else: ""
    let target = if cmdPath.len > 0: ctx.progName & " help " & cmdPath else: ctx.progName & " help"
    sections.add "Run '" & target & "' for more information on a command."

  sections.join("\n\n")

proc renderUsage*(ctx: HelpContext): string =
  ## Renders a short usage line for error contexts.
  if ctx.cmd.usageRenderer != nil:
    return ctx.cmd.usageRenderer(ctx.cmd, ctx.path, ctx.progName)
  "Usage: " & buildUsageLine(ctx)

proc helpForPath*(root: Command; path: seq[string]; progName: string): string =
  ## Renders help output for a command path, returning an error string if the path cannot be resolved.
  var cmd = root

  for tok in path:
    var matched: Command = nil
    for child in cmd.subcommands:
      if child.name == tok or child.aliases.anyIt(it == tok):
        matched = child
        break

    if matched == nil:
      return "unknown command: " & tok

    cmd = matched

  let ctx = HelpContext(cmd: cmd, path: path, progName: progName)
  renderHelp(ctx)
