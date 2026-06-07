import std/[tables]

type
  Command* = ref object ## A CLI command node (root or subcommand) in the Nimancer command tree.
    name*: string
    aliases*: seq[string]
    description*: string
    options*: seq[OptionSpec]
    arguments*: seq[ArgSpec]
    subcommands*: seq[Command]
    parent*: Command
    actionCb*: ActionProc
    preRunCb*: HookProc
    postRunCb*: HookProc
    silenceErrors*: bool
    silenceUsage*: bool
    helpRenderer*: HelpRendererProc
    usageRenderer*: UsageRendererProc

  ValueKind* = enum
    vkNone
    vkInt

  OptionSpec* = object ## Declares one option/flag accepted by a command (including aliases and defaults).
    shortFlag*: string
    longFlag*: string
    description*: string
    defaultValue*: string
    isBool*: bool
    isNegatable*: bool
    required*: bool
    valueName*: string
    valueKind*: ValueKind

  ArgSpec* = object ## Declares one positional argument accepted by a command.
    name*: string
    description*: string
    defaultValue*: string
    required*: bool
    variadic*: bool

  CommandContext* = object ## Captures the resolved command invocation: selected command, parsed options, and args.
    options*: Table[string, string]
    args*: seq[string]
    rawArgs*: seq[string]
    command*: Command

  ParseResult* = object ## Result of parsing argv: either a runnable command context, a help request, or an error.
    command*: Command
    ctx*: CommandContext
    helpRequested*: bool
    error*: string

  ActionProc* = proc(ctx: CommandContext): int {.closure.}
  HookProc* = proc(ctx: CommandContext) {.closure.}
  HelpRendererProc* = proc(cmd: Command; path: seq[string]; progName: string): string {.closure.}
  UsageRendererProc* = proc(cmd: Command; path: seq[string]; progName: string): string {.closure.}

proc newCommand*(name: string): Command =
  ## Constructs a new command node with default-initialized fields.
  Command(
    name: name,
    aliases: @[],
    description: "",
    options: @[],
    arguments: @[],
    subcommands: @[],
    parent: nil,
    actionCb: nil,
    preRunCb: nil,
    postRunCb: nil,
    silenceErrors: false,
    silenceUsage: false,
    helpRenderer: nil,
    usageRenderer: nil
  )
