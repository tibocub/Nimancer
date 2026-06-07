import std/[strutils]

import nimancer/types

proc optionExists(cmd: Command; shortFlag, longFlag: string): bool =
  for opt in cmd.options:
    if shortFlag.len > 0 and opt.shortFlag == shortFlag:
      return true
    if longFlag.len > 0 and opt.longFlag == longFlag:
      return true
  false

proc addHelpOptionIfMissing(cmd: Command) =
  if optionExists(cmd, "h", "help"):
    return
  cmd.options.add OptionSpec(
    shortFlag: "h",
    longFlag: "help",
    description: "Show help",
    defaultValue: "false",
    isBool: true,
    isNegatable: false,
    required: false,
    valueName: "",
    valueKind: vkNone
  )

proc parseArgSpec(spec: string; description: string; defaultValue: string): ArgSpec =
  let s = spec.strip()
  if s.len < 2:
    raise newException(ValueError, "invalid argument spec: '" & spec & "'")

  if s[0] == '<' and s[^1] == '>':
    result = ArgSpec(
      name: s[1 ..< s.high],
      description: description,
      defaultValue: defaultValue,
      required: true,
      variadic: false
    )
    return

  if s[0] == '[' and s[^1] == ']':
    result = ArgSpec(
      name: s[1 ..< s.high],
      description: description,
      defaultValue: defaultValue,
      required: false,
      variadic: false
    )
    return

  raise newException(ValueError, "invalid argument spec: '" & spec & "'")

proc parseCommandNameAndArgs(nameAndArgs: string): tuple[name: string, args: seq[string]] =
  let parts = nameAndArgs.strip().splitWhitespace()
  if parts.len == 0:
    raise newException(ValueError, "command name is empty")

  result.name = parts[0]
  result.args = @[]
  for i in 1 ..< parts.len:
    let p = parts[i]
    if (p.len >= 2 and ((p[0] == '<' and p[^1] == '>') or (p[0] == '[' and p[^1] == ']'))):
      result.args.add p
    else:
      break

proc parseValueSpecToken(tok: string): tuple[valueName: string, valueKind: ValueKind] =
  let inner = tok[1 ..< tok.high]
  let parts = inner.split(':', maxsplit = 1)
  result.valueName = parts[0]
  result.valueKind = vkNone
  if parts.len == 2:
    case parts[1]
    of "int":
      result.valueKind = vkInt
    else:
      raise newException(ValueError, "unknown value type: '" & parts[1] & "'")

proc parseOptionFlags(flags: string): tuple[shortFlag: string, longFlag: string, isBool: bool, isNegatable: bool, valueName: string, valueKind: ValueKind] =
  var shortFlag = ""
  var longFlag = ""
  var expectsValue = false
  var isNegatable = false
  var valueName = ""
  var valueKind = vkNone

  let tokens = flags.strip().splitWhitespace()
  if tokens.len == 0:
    raise newException(ValueError, "flags string is empty")

  for tok in tokens:
    let t = tok.strip(chars = {' ', ','})
    if t.len == 0:
      continue

    if t.len >= 2 and t[0] == '<' and t[^1] == '>':
      expectsValue = true
      let parsed = parseValueSpecToken(t)
      valueName = parsed.valueName
      valueKind = parsed.valueKind
      continue

    if t.len >= 3 and t[0..1] == "--":
      var name = t[2..^1]
      if name.startsWith("no-"):
        isNegatable = true
        name = name[3..^1]
      longFlag = name
      continue

    if t.len >= 2 and t[0] == '-':
      if t.len == 2:
        shortFlag = $t[1]
      else:
        shortFlag = t[1..^1]
      continue

  if shortFlag.len == 0 and longFlag.len == 0:
    raise newException(ValueError, "could not parse flags: '" & flags & "'")

  result.shortFlag = shortFlag
  result.longFlag = longFlag
  result.isBool = not expectsValue
  result.isNegatable = isNegatable
  result.valueName = valueName
  result.valueKind = valueKind

proc initProgram*(name: string): Command =
  ## Creates the root command and registers the default help option and `help` subcommand.
  result = newCommand(name)
  result.addHelpOptionIfMissing()

  let helpCmd = newCommand("help")
  helpCmd.parent = result
  helpCmd.description = "Show help for a command"
  helpCmd.arguments.add ArgSpec(
    name: "command",
    description: "",
    defaultValue: "",
    required: false,
    variadic: true
  )
  helpCmd.addHelpOptionIfMissing()
  result.subcommands.add helpCmd

proc command*(parent: Command; nameAndArgs: string): Command =
  ## Creates a subcommand under `parent` from a Commander-style `nameAndArgs` string.
  let parsed = parseCommandNameAndArgs(nameAndArgs)

  result = newCommand(parsed.name)
  result.parent = parent

  for a in parsed.args:
    result.arguments.add parseArgSpec(a, "", "")

  result.addHelpOptionIfMissing()
  parent.subcommands.add result

proc alias*(cmd: Command; name: string): Command =
  ## Adds an alias to a command.
  if name.len > 0:
    cmd.aliases.add name
  cmd

proc description*(cmd: Command; text: string): Command =
  ## Sets the command description.
  cmd.description = text
  cmd

proc option*(cmd: Command; flags: string; description: string = ""; defaultValue: string = ""): Command =
  ## Declares a Commander-style option for the command.
  let parsed = parseOptionFlags(flags)

  var dv = defaultValue
  if parsed.isNegatable and dv.len == 0:
    dv = "true"

  if cmd.optionExists(parsed.shortFlag, parsed.longFlag):
    return cmd

  cmd.options.add OptionSpec(
    shortFlag: parsed.shortFlag,
    longFlag: parsed.longFlag,
    description: description,
    defaultValue: dv,
    isBool: parsed.isBool,
    isNegatable: parsed.isNegatable,
    required: false,
    valueName: parsed.valueName,
    valueKind: parsed.valueKind
  )

  cmd

proc argument*(cmd: Command; spec: string; description: string = ""; defaultValue: string = ""): Command =
  ## Declares a positional argument for the command.
  cmd.arguments.add parseArgSpec(spec, description, defaultValue)
  cmd

proc action*(cmd: Command; cb: ActionProc): Command =
  ## Sets the action callback for the command.
  cmd.actionCb = cb
  cmd

proc preRun*(cmd: Command; cb: HookProc): Command =
  ## Sets the pre-run hook for the command.
  cmd.preRunCb = cb
  cmd

proc postRun*(cmd: Command; cb: HookProc): Command =
  ## Sets the post-run hook for the command.
  cmd.postRunCb = cb
  cmd

proc silenceErrors*(cmd: Command; enabled: bool = true): Command =
  ## Enables or disables automatic error printing.
  cmd.silenceErrors = enabled
  cmd

proc silenceUsage*(cmd: Command; enabled: bool = true): Command =
  ## Enables or disables automatic usage printing on errors.
  cmd.silenceUsage = enabled
  cmd

proc setHelpRenderer*(cmd: Command; r: HelpRendererProc): Command =
  ## Sets a custom help renderer for this command.
  cmd.helpRenderer = r
  cmd

proc setUsageRenderer*(cmd: Command; r: UsageRendererProc): Command =
  ## Sets a custom usage renderer for this command.
  cmd.usageRenderer = r
  cmd
