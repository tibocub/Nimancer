import std/[unittest]

import nimancer/run
import nimancer/dsl

suite "dsl":
  test "action(var1, ...) assigns from ctx and runs":
    let prog = cli("app"):
      command "more-complex":
        opt(seriously, bool, "-s", "--seriously", "Seriously complex option")
        opt(ultra, bool, "-u", "--ultra", "Ultra complex option")
        opt(complexity, string, "-c", "--complexity", "<complexity:int>", "Handle complexity level", "1")

        action(seriously, ultra, complexity):
          if seriously and ultra and complexity == "3":
            return 7
          return 0

    check run(prog, @["more-complex", "--seriously", "--ultra", "--complexity:3"]) == 7
    check run(prog, @["more-complex", "--seriously"]) == 0
    check run(prog, @["more-complex", "--complexity:wat"]) == 1
