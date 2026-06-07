import std/[macros, options]

import ./types
import ./builders as b
import ./values as values

template cli*(name: string; body: untyped): Command =
  block:
    let prog {.inject.} = b.initProgram(name)
    body
    prog

template command*(spec: string; body: untyped) =
  block:
    let cmd {.inject.} = b.command(prog, spec)
    body

template command*(parent: Command; spec: string; body: untyped) =
  block:
    let cmd {.inject.} = b.command(parent, spec)
    body

template desc*(text: string) =
  when declared(cmd):
    discard b.description(cmd, text)
  else:
    discard b.description(prog, text)

template alias*(name: string) =
  discard b.alias(cmd, name)

template opt*(ident: untyped; t: typedesc[bool]; shortFlag: string; longFlag: string; description: string) =
  var `ident` {.inject.}: bool = false
  discard b.option(cmd, shortFlag & ", " & longFlag, description)

template opt*(ident: untyped; t: typedesc[string]; shortFlag: string; longFlag: string; valueSpec: string; description: string; defaultValue: string = "") =
  var `ident` {.inject.}: string = defaultValue
  let placeholder =
    if valueSpec.len > 0:
      if valueSpec[0] == '<':
        valueSpec
      else:
        "<" & valueSpec & ">"
    elif longFlag.len > 2 and longFlag[0..1] == "--":
      "<" & longFlag[2..^1] & ">"
    else:
      "<value>"

  discard b.option(cmd, shortFlag & ", " & longFlag & " " & placeholder, description, defaultValue)

template opt*(ident: untyped; t: typedesc[string]; shortFlag: string; longFlag: string; description: string; defaultValue: string = "") =
  opt(ident, t, shortFlag, longFlag, "", description, defaultValue)

proc flag*(ctx: CommandContext; key: string): bool =
  values.flag(ctx, key)

proc optOr*(ctx: CommandContext; key: string; defaultValue: string): string =
  values.optOr(ctx, key, defaultValue)

proc arg*(ctx: CommandContext; idx: int): Option[string] =
  values.arg(ctx, idx)

proc argOr*(ctx: CommandContext; idx: int; defaultValue: string): string =
  values.argOr(ctx, idx, defaultValue)

proc actionVal*[T](ctx: CommandContext; key: string; defaultValue: T): T =
  when T is bool:
    values.flag(ctx, key)
  elif T is string:
    values.optOr(ctx, key, defaultValue)
  else:
    {.error: "unsupported action variable type for '" & key & "'".}

macro action*(args: varargs[untyped]): untyped =
  ## DSL action.
  ##
  ## Supported forms:
  ## - action:
  ##     <statements returning int>
  ## - action(flag1, opt1, ...):
  ##     <statements returning int>
  ##
  ## In the second form, each identifier is assigned from `ctx` by name before `body` runs:
  ## - bool vars use `values.flag(ctx, "name")`
  ## - string vars use `values.optOr(ctx, "name", <current default>)`

  let ctxParam = genSym(nskParam, "ctx")

  if args.len == 1:
    let body = args[0]
    result = quote do:
      discard b.action(cmd, proc(`ctxParam`: CommandContext): int =
        `body`
      )
    return

  if args.len < 2:
    error("expected 'action:' or 'action(var1, var2, ...):'", args)

  let body = args[^1]

  var assigns = newStmtList()

  var varIdents: seq[NimNode] = @[]
  for i in 0 ..< args.len - 1:
    varIdents.add args[i]

  for v in varIdents:
    if v.kind != nnkIdent:
      error("expected identifier in action(var1, var2, ...)", v)

    let keyLit = newLit(v.strVal)
    assigns.add quote do:
      let `v` = actionVal(`ctxParam`, `keyLit`, `v`)

  result = quote do:
    discard b.action(cmd, proc(`ctxParam`: CommandContext): int =
      `assigns`
      `body`
    )
