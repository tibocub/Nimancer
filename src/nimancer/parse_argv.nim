import std/[strutils]
from std/tables import initTable, `[]=`

import ./types

proc validateOptionValue(opt: OptionSpec; value: string): bool =
  case opt.valueKind
  of vkNone:
    true
  of vkInt:
    try:
      discard parseInt(value)
      true
    except ValueError:
      false

proc optionKey(opt: OptionSpec): string =
  if opt.longFlag.len > 0:
    return opt.longFlag
  opt.shortFlag

proc withError(cmd: Command; ctx: CommandContext; msg: string): ParseResult =
  result.command = cmd
  result.ctx = ctx
  result.error = msg

proc resolveCommand*(root: Command; tokens: seq[string]): tuple[cmd: Command; remaining: seq[string]] =
  ## Resolves the most specific subcommand path from `tokens` and returns the matched command and remaining tokens.
  var cmd = root
  var idx = 0

  while idx < tokens.len:
    let tok = tokens[idx]
    var matched: Command = nil

    for child in cmd.subcommands:
      if child.name == tok:
        matched = child
        break
      for a in child.aliases:
        if a == tok:
          matched = child
          break
      if matched != nil:
        break

    if matched == nil:
      break

    cmd = matched
    inc idx

  result.cmd = cmd
  if idx < tokens.len:
    result.remaining = tokens[idx..^1]
  else:
    result.remaining = @[]

proc findOption*(cmd: Command; flag: string): OptionSpec =
  ## Finds an option on `cmd` by short or long flag name (handling `no-` for negatable booleans).
  var key = flag
  var isNegated = false

  if key.startsWith("no-"):
    isNegated = true
    key = key[3..^1]

  for opt in cmd.options:
    if opt.shortFlag.len > 0 and opt.shortFlag == key:
      if isNegated:
        break
      return opt
    if opt.longFlag.len > 0 and opt.longFlag == key:
      if isNegated and not opt.isNegatable:
        break
      return opt

  raise newException(KeyError, "option not found")

proc parseArgv*(root: Command; argv: seq[string]): ParseResult =
  ## Parses argv into a `ParseResult` containing the resolved command, context, and any help/error flags.
  var filtered: seq[string] = @[]
  for t in argv:
    if t != "--":
      filtered.add t

  let resolved = resolveCommand(root, filtered)
  let cmd = resolved.cmd
  let remaining = resolved.remaining

  for t in remaining:
    if t == "-h" or t == "--help":
      result.command = cmd
      result.helpRequested = true
      return

  var ctx = CommandContext(
    options: initTable[string, string](),
    args: @[],
    rawArgs: @[],
    command: cmd
  )

  for opt in cmd.options:
    ctx.options[optionKey(opt)] = opt.defaultValue

  var positionals: seq[string] = @[]
  var i = 0
  while i < remaining.len:
    let tok = remaining[i]

    if tok == "--":
      inc i
      continue

    if tok.startsWith("--no-"):
      let raw = tok[2..^1]
      try:
        let opt = findOption(cmd, raw)
        if not opt.isNegatable:
          return withError(cmd, ctx, "unknown option: " & tok)
        ctx.options[optionKey(opt)] = "false"
      except KeyError:
        return withError(cmd, ctx, "unknown option: " & tok)

      inc i
      continue

    if tok.startsWith("--"):
      let body = tok[2..^1]
      var sepPos = body.find('=')
      if sepPos < 0:
        sepPos = body.find(':')
      if sepPos >= 0:
        let name = body[0..<sepPos]
        let value = body[(sepPos + 1)..^1]
        try:
          let opt = findOption(cmd, name)
          if opt.isBool:
            ctx.options[optionKey(opt)] = "true"
          else:
            if not validateOptionValue(opt, value):
              return withError(cmd, ctx, "invalid value for option: --" & name)
            ctx.options[optionKey(opt)] = value
        except KeyError:
          return withError(cmd, ctx, "unknown option: --" & name)

        inc i
        continue

      try:
        let opt = findOption(cmd, body)
        if opt.isBool:
          ctx.options[optionKey(opt)] = "true"
        else:
          if i + 1 >= remaining.len:
            return withError(cmd, ctx, "missing value for option: --" & body)
          let value = remaining[i + 1]
          if not validateOptionValue(opt, value):
            return withError(cmd, ctx, "invalid value for option: --" & body)
          ctx.options[optionKey(opt)] = value
          inc i
      except KeyError:
        return withError(cmd, ctx, "unknown option: --" & body)

      inc i
      continue

    if tok.startsWith("-") and tok.len > 3 and (tok[2] == '=' or tok[2] == ':'):
      let name = $tok[1]
      let value = tok[3..^1]
      try:
        let opt = findOption(cmd, name)
        if opt.isBool:
          ctx.options[optionKey(opt)] = "true"
        else:
          if value.len == 0:
            return withError(cmd, ctx, "missing value for option: -" & name)
          if not validateOptionValue(opt, value):
            return withError(cmd, ctx, "invalid value for option: -" & name)
          ctx.options[optionKey(opt)] = value
      except KeyError:
        return withError(cmd, ctx, "unknown option: -" & name)

      inc i
      continue

    if tok.startsWith("-") and tok.len > 2:
      var ok = true
      for j in 1 ..< tok.len:
        let ch = $tok[j]
        try:
          let opt = findOption(cmd, ch)
          if not opt.isBool:
            ok = false
            break
          ctx.options[optionKey(opt)] = "true"
        except KeyError:
          ok = false
          break

      if not ok:
        return withError(cmd, ctx, "unknown option: " & tok)

      inc i
      continue

    if tok.startsWith("-") and tok.len == 2:
      let name = $tok[1]
      try:
        let opt = findOption(cmd, name)
        if opt.isBool:
          ctx.options[optionKey(opt)] = "true"
        else:
          if i + 1 >= remaining.len:
            return withError(cmd, ctx, "missing value for option: -" & name)
          let value = remaining[i + 1]
          if not validateOptionValue(opt, value):
            return withError(cmd, ctx, "invalid value for option: -" & name)
          ctx.options[optionKey(opt)] = value
          inc i
      except KeyError:
        return withError(cmd, ctx, "unknown option: -" & name)

      inc i
      continue

    positionals.add tok
    inc i

  var posIdx = 0
  for spec in cmd.arguments:
    if spec.variadic:
      if posIdx < positionals.len:
        ctx.args.add positionals[posIdx..^1]
        posIdx = positionals.len
      break

    if posIdx < positionals.len:
      ctx.args.add positionals[posIdx]
      inc posIdx
    else:
      if spec.required and spec.defaultValue.len == 0:
        return withError(cmd, ctx, "missing required argument: <" & spec.name & ">")
      if spec.defaultValue.len > 0:
        ctx.args.add spec.defaultValue

  if posIdx < positionals.len:
    return withError(cmd, ctx, "unexpected argument: " & positionals[posIdx])

  result.command = cmd
  result.ctx = ctx
