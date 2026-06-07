import std/[options, strutils]
from std/tables import hasKey, `[]`

import ./types

proc opt*(ctx: CommandContext; key: string): Option[string] =
  if ctx.options.hasKey(key):
    return some(ctx.options[key])
  none(string)

proc optOr*(ctx: CommandContext; key: string; defaultValue: string): string =
  let v = ctx.opt(key)
  if v.isSome:
    return v.get
  defaultValue

proc flag*(ctx: CommandContext; key: string): bool =
  let v = ctx.opt(key)
  if v.isSome:
    try:
      return parseBool(v.get)
    except ValueError:
      return false
  false

proc arg*(ctx: CommandContext; idx: int): Option[string] =
  if idx >= 0 and idx < ctx.args.len:
    return some(ctx.args[idx])
  none(string)

proc argOr*(ctx: CommandContext; idx: int; defaultValue: string): string =
  let v = ctx.arg(idx)
  if v.isSome:
    return v.get
  defaultValue
