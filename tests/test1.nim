import std/[unittest, tables]
import std/strutils

import nimancer

suite "builders":
  test "initProgram registers help option and help subcommand":
    let prog = initProgram("app")

    check prog.subcommands.len == 1
    check prog.subcommands[0].name == "help"

    var hasHelp = false
    for o in prog.options:
      if o.shortFlag == "h" and o.longFlag == "help":
        hasHelp = true
        check o.isBool
        break
    check hasHelp

  test "command(\"add <path>\") sets name, args, parent":
    let prog = initProgram("app")
    let addCmd = prog.command("add <path>")

    check addCmd.name == "add"
    check addCmd.parent == prog
    check addCmd.arguments.len == 1
    check addCmd.arguments[0].name == "path"
    check addCmd.arguments[0].required

  test "alias appends":
    let prog = initProgram("app")
    let addCmd = prog.command("add")

    discard addCmd.alias("a")
    check addCmd.aliases == @["a"]

  test "option -n, --name <value> parses as value option":
    let prog = initProgram("app")
    let addCmd = prog.command("add")

    discard addCmd.option("-n, --name <value>")

    var found = false
    for o in addCmd.options:
      if o.shortFlag == "n" and o.longFlag == "name":
        found = true
        check o.isBool == false
        break
    check found

  test "option -f, --force parses as bool option":
    let prog = initProgram("app")
    let addCmd = prog.command("add")

    discard addCmd.option("-f, --force")

    var found = false
    for o in addCmd.options:
      if o.shortFlag == "f" and o.longFlag == "force":
        found = true
        check o.isBool
        break
    check found

  test "option --no-color parses negatable and defaults true":
    let prog = initProgram("app")
    let addCmd = prog.command("add")

    discard addCmd.option("--no-color")

    var found = false
    for o in addCmd.options:
      if o.longFlag == "color":
        found = true
        check o.isNegatable
        check o.isBool
        check o.defaultValue == "true"
        break
    check found

  test "option does not add duplicate -h/--help":
    let prog = initProgram("app")
    discard prog.option("-h, --help")

    var count = 0
    for o in prog.options:
      if o.shortFlag == "h" and o.longFlag == "help":
        inc count
    check count == 1

  test "argument spec parses required and optional":
    let prog = initProgram("app")
    let cmd = prog.command("add")

    discard cmd.argument("<file>")
    discard cmd.argument("[out]")

    check cmd.arguments.len == 2
    check cmd.arguments[0].name == "file"
    check cmd.arguments[0].required
    check cmd.arguments[1].name == "out"
    check cmd.arguments[1].required == false

suite "parse_argv":
  test "resolveCommand resolves subcommand by name":
    let prog = initProgram("app")
    discard prog.command("add <path>")

    let resolved = resolveCommand(prog, @["add", "foo"])
    check resolved.cmd.name == "add"
    check resolved.remaining == @["foo"]

  test "resolveCommand resolves subcommand by alias":
    let prog = initProgram("app")
    let addCmd = prog.command("add <path>")
    discard addCmd.alias("a")

    let resolved = resolveCommand(prog, @["a", "foo"])
    check resolved.cmd.name == "add"
    check resolved.remaining == @["foo"]

  test "--name value sets options[name]":
    let prog = initProgram("app")
    discard prog.command("add <path>").option("-n, --name <value>")

    let parsed = parseArgv(prog, @["add", "--name", "value", "x"])
    check parsed.error.len == 0
    check parsed.ctx.options["name"] == "value"

  test "--name=value sets options[name]":
    let prog = initProgram("app")
    discard prog.command("add <path>").option("-n, --name <value>")

    let parsed = parseArgv(prog, @["add", "--name=value", "x"])
    check parsed.error.len == 0
    check parsed.ctx.options["name"] == "value"

  test "--name:value sets options[name]":
    let prog = initProgram("app")
    discard prog.command("add <path>").option("-n, --name <value>")

    let parsed = parseArgv(prog, @["add", "--name:value", "x"])
    check parsed.error.len == 0
    check parsed.ctx.options["name"] == "value"

  test "-n value sets options[name]":
    let prog = initProgram("app")
    discard prog.command("add <path>").option("-n, --name <value>")

    let parsed = parseArgv(prog, @["add", "-n", "value", "x"])
    check parsed.error.len == 0
    check parsed.ctx.options["name"] == "value"

  test "-n:value sets options[name]":
    let prog = initProgram("app")
    discard prog.command("add <path>").option("-n, --name <value>")

    let parsed = parseArgv(prog, @["add", "-n:value", "x"])
    check parsed.error.len == 0
    check parsed.ctx.options["name"] == "value"

  test "-f sets options[force] true":
    let prog = initProgram("app")
    discard prog.command("add").option("-f, --force")

    let parsed = parseArgv(prog, @["add", "-f"])
    check parsed.error.len == 0
    check parsed.ctx.options["force"] == "true"

  test "-fv short bundle sets both bools":
    let prog = initProgram("app")
    let cmd = prog.command("add")
    discard cmd.option("-f, --force")
    discard cmd.option("-v, --verbose")

    let parsed = parseArgv(prog, @["add", "-fv"])
    check parsed.error.len == 0
    check parsed.ctx.options["force"] == "true"
    check parsed.ctx.options["verbose"] == "true"

  test "--no-color sets options[color] false":
    let prog = initProgram("app")
    discard prog.command("add").option("--no-color")

    let parsed = parseArgv(prog, @["add", "--no-color"])
    check parsed.error.len == 0
    check parsed.ctx.options["color"] == "false"

  test "-- is ignored":
    let prog = initProgram("app")
    discard prog.command("add [x]").option("-f, --force")

    let parsed = parseArgv(prog, @["add", "--", "-f", "x"])
    check parsed.error.len == 0
    check parsed.ctx.options["force"] == "true"
    check parsed.ctx.rawArgs.len == 0

  test "positionals map onto declared args":
    let prog = initProgram("app")
    discard prog.command("add <a> [b]")

    let parsed = parseArgv(prog, @["add", "one", "two"])
    check parsed.error.len == 0
    check parsed.ctx.args == @["one", "two"]

  test "extra positionals set error":
    let prog = initProgram("app")
    discard prog.command("add <a>")

    let parsed = parseArgv(prog, @["add", "one", "two", "three"])
    check parsed.error.len > 0

  test "missing required arg sets error":
    let prog = initProgram("app")
    discard prog.command("add <a>")

    let parsed = parseArgv(prog, @["add"])
    check parsed.error.len > 0

  test "unknown option sets error":
    let prog = initProgram("app")
    discard prog.command("add")

    let parsed = parseArgv(prog, @["add", "--wat"])
    check parsed.error.len > 0

  test "-h anywhere sets helpRequested":
    let prog = initProgram("app")
    discard prog.command("add")

    let parsed = parseArgv(prog, @["add", "-h"])
    check parsed.helpRequested
    check parsed.error.len == 0
    check parsed.command.name == "add"

  test "--help after subcommand sets helpRequested for that subcommand":
    let prog = initProgram("app")
    discard prog.command("add")

    let parsed = parseArgv(prog, @["add", "--help"])
    check parsed.helpRequested
    check parsed.command.name == "add"

suite "help":
  test "buildUsageLine includes [command] only when real subcommands exist":
    block:
      let prog = initProgram("app")
      let ctx = HelpContext(cmd: prog, path: @[], progName: prog.name)
      let usage = buildUsageLine(ctx)
      check not usage.contains("[command]")

    block:
      let prog = initProgram("app")
      discard prog.command("add")
      let ctx = HelpContext(cmd: prog, path: @[], progName: prog.name)
      let usage = buildUsageLine(ctx)
      check usage.contains("[command]")

  test "buildUsageLine includes [options] when options exist":
    let prog = initProgram("app")
    let cmd = prog.command("add")
    discard cmd.option("-f, --force")

    let ctx = HelpContext(cmd: cmd, path: @["add"], progName: prog.name)
    let usage = buildUsageLine(ctx)
    check usage.contains("[options]")

  test "buildUsageLine includes <arg> and [arg]":
    let prog = initProgram("app")
    let cmd = prog.command("add <file> [out]")
    let ctx = HelpContext(cmd: cmd, path: @["add"], progName: prog.name)
    let usage = buildUsageLine(ctx)
    check usage.contains("<file>")
    check usage.contains("[out]")

  test "renderHelp includes description when set":
    let prog = initProgram("app")
    let cmd = prog.command("add")
    discard cmd.description("Add something")

    let ctx = HelpContext(cmd: cmd, path: @["add"], progName: prog.name)
    let helpText = renderHelp(ctx)
    check helpText.contains("Add something")

  test "renderHelp omits description when empty":
    let prog = initProgram("app")
    let cmd = prog.command("add")

    let ctx = HelpContext(cmd: cmd, path: @["add"], progName: prog.name)
    let helpText = renderHelp(ctx)
    check not helpText.contains("\n\n\n")

  test "renderHelp excludes help from Commands section":
    let prog = initProgram("app")
    discard prog.command("add")
    let ctx = HelpContext(cmd: prog, path: @[], progName: prog.name)
    let helpText = renderHelp(ctx)
    check helpText.contains("Commands:")
    check not helpText.contains("\n  help")

  test "renderHelp includes footer only when real subcommands exist":
    block:
      let prog = initProgram("app")
      let ctx = HelpContext(cmd: prog, path: @[], progName: prog.name)
      let helpText = renderHelp(ctx)
      check not helpText.contains("Run '")

    block:
      let prog = initProgram("app")
      discard prog.command("add")
      let ctx = HelpContext(cmd: prog, path: @[], progName: prog.name)
      let helpText = renderHelp(ctx)
      check helpText.contains("Run '")

  test "helpForPath returns help for nested path":
    let prog = initProgram("app")
    let remote = prog.command("remote")
    discard remote.command("add <name>")

    let helpText = helpForPath(prog, @["remote", "add"], prog.name)
    check helpText.contains("Usage:")
    check helpText.contains("remote add")

  test "helpForPath returns unknown command on bad path":
    let prog = initProgram("app")
    let msg = helpForPath(prog, @["wat"], prog.name)
    check msg == "unknown command: wat"

suite "run":
  test "parse error returns 1":
    let prog = initProgram("app")
    discard prog.command("add")
    let code = run(prog, @["add", "--unknown"])
    check code == 1

  test "-h on root returns 0":
    let prog = initProgram("app")
    let code = run(prog, @["-h"])
    check code == 0

  test "-h on subcommand returns 0":
    let prog = initProgram("app")
    discard prog.command("add")
    let code = run(prog, @["add", "-h"])
    check code == 0

  test "help subcommand with no args returns 0":
    let prog = initProgram("app")
    let code = run(prog, @["help"])
    check code == 0

  test "help remote returns 0":
    let prog = initProgram("app")
    discard prog.command("remote")
    let code = run(prog, @["help", "remote"])
    check code == 0

  test "no action set returns 0":
    let prog = initProgram("app")
    discard prog.command("add")
    let code = run(prog, @["add"])
    check code == 0

  test "action return code is propagated":
    let prog = initProgram("app")
    let cmd = prog.command("add")
    discard cmd.action(proc(ctx: CommandContext): int = 42)
    let code = run(prog, @["add"])
    check code == 42

  test "preRun and postRun wrap action in order":
    let prog = initProgram("app")
    let cmd = prog.command("add")

    var calls: seq[string] = @[]
    discard cmd.preRun(proc(ctx: CommandContext) = calls.add "pre")
    discard cmd.action(proc(ctx: CommandContext): int =
      calls.add "action"
      0
    )
    discard cmd.postRun(proc(ctx: CommandContext) = calls.add "post")

    let code = run(prog, @["add"])
    check code == 0
    check calls == @["pre", "action", "post"]
