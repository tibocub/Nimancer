import nimancer/run
import nimancer/dsl

import std/[strutils]

when isMainModule:
  let prog = cli("basic"):
    desc "A basic CLI example using Nimancer"

    command "hello":
      desc "Say hello"
      action:
        stdout.writeLine "Hello, world!"
        0

    command "test":
      alias "t"
      desc "Test command"
      action:
        stdout.writeLine "Test command"
        0

    command "more-complex":
      desc "A more complex command with options"
      opt(seriously, bool, "-s", "--seriously", "Seriously complex option")
      opt(ultra, bool, "-u", "--ultra", "Ultra complex option")
      opt(complexity, string, "-c", "--complexity", "<complexity:int>", "Handle complexity level", "1")

      action(seriously, ultra, complexity):
        let complexityInt =
          try:
            parseInt(complexity)
          except ValueError:
            1

        if complexityInt > 0:
          let very = repeat("very ", complexityInt)
          if seriously and ultra:
            stdout.writeLine "A seriously " & very & "ultra complex command"
          elif seriously:
            stdout.writeLine "A seriously " & very & "complex command"
          elif ultra:
            stdout.writeLine "A " & repeat("ultra ", complexityInt) & "complex command"
          else:
            stdout.writeLine "A " & very & "complex command"
        else:
          if ultra and seriously:
            stdout.writeLine "A seriously ultra complex command"
          elif ultra:
            stdout.writeLine "Ultra complex command"
          elif seriously:
            stdout.writeLine "Seriously complex command"
          else:
            stdout.writeLine "Complex command"
        0

  quit(run(prog))
