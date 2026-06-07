import nimancer
import std/os
import std/strutils

var todos: seq[string] = @[]

let dataPath = joinPath(currentSourcePath().splitFile.dir, "todo.txt")

proc loadTodos() =
  todos = @[]
  if not fileExists(dataPath):
    return
  for line in lines(dataPath):
    let t = line.strip()
    if t.len > 0:
      todos.add t

proc saveTodos() =
  writeFile(dataPath, todos.join("\n") & (if todos.len > 0: "\n" else: ""))

proc parseIndex(s: string): int =
  try:
    parseInt(s)
  except ValueError:
    -1

when isMainModule:
  loadTodos()

  let prog = initProgram("todo")
  discard prog.description("A tiny todo CLI example using Nimancer")

  discard prog.preRun(proc(ctx: CommandContext) =
    stdout.writeLine "[todo] running: " & ctx.command.name
  )

  let addCmd = prog.command("add <task>")
  discard addCmd.alias("a")
  discard addCmd.description("Add a new task")
  discard addCmd.option("-p, --priority <level>", "Task priority", "normal")
  discard addCmd.action(proc(ctx: CommandContext): int =
    let task = ctx.argOr(0, "")
    if task.len == 0:
      stderr.writeLine "Error: missing task"
      return 1

    let prio = ctx.optOr("priority", "normal")
    todos.add "[" & prio & "] " & task
    saveTodos()
    stdout.writeLine "Added: " & task
    0
  )

  let listCmd = prog.command("list")
  discard listCmd.alias("ls")
  discard listCmd.description("List tasks")
  discard listCmd.option("-f, --filter <text>", "Filter tasks", "")
  discard listCmd.action(proc(ctx: CommandContext): int =
    loadTodos()
    let f = ctx.optOr("filter", "")
    if todos.len == 0:
      stdout.writeLine "(no tasks)"
      return 0

    for i, t in todos:
      if f.len == 0 or t.contains(f):
        stdout.writeLine $(i + 1) & ". " & t
    0
  )

  let doneCmd = prog.command("done <index>")
  discard doneCmd.description("Mark a task done")
  discard doneCmd.option("--force", "Skip bounds checks")
  discard doneCmd.action(proc(ctx: CommandContext): int =
    loadTodos()
    let idx = parseIndex(ctx.argOr(0, ""))
    let force = ctx.flag("force")

    if idx <= 0:
      stderr.writeLine "Error: index must be a positive integer"
      return 1

    let i = idx - 1
    if not force and (i < 0 or i >= todos.len):
      stderr.writeLine "Error: index out of range"
      return 1

    if i >= 0 and i < todos.len:
      stdout.writeLine "Done: " & todos[i]
      todos.delete(i)
      saveTodos()
      return 0

    stderr.writeLine "Error: cannot mark done"
    1
  )

  quit(run(prog))
