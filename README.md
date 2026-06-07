# Nimancer



```
-mancy (suffix)
    Word-forming element of Greek origin meaning "divination by means of"

Nimancy (n.)
    "divination by the mean of" NIM

Nimancer (n.)
    nimmanser, nimrodmauncere, "sorcerer, adept in Nim magic," from nimromancie (see nimromancy).
    Properly "one who communicates with Nim" but typically used in a broader sense in English.

```

Basically [Commander.js](https://github.com/tj/commander.js) for Nim.


### Why Nimancer? There are already so much arg parsers for Nim!
That's right but according to my taste, no one recreated such a pleasant workflow as Commander.js
and I thought that with Nim meta-programming capabilities, it was totally possible to recreate something
as clean, intuitive and reliable as Commander.


## Features
Simply create commands, options and arguments, and Nimancer will handle the rest.
Nimancer tries its best to check the command before executing it. You can let Nimancer handle the validation of the types of the arguments and options by specifying the type , or you can do it yourself.

## TODO
- [x] help usage generator
- [WIP] commands
  - [x] main commands
  - [x] options
  - [ ] subcommands


## TO FIX
- [ ] "basic-cli help test" should show the help for the test command, not the general help ("basic-cli test -h" already work as intended and show's the test command help)

- [ ] opt(complexity, string, "-c", "--complexity", "Handle complexity level", "1") should work without the default value when no value is provided and count "1" as the specified default value, but basic_cli fails when "-c" is used without a value. When "-c" is given a bad value, it succeeds and use the default value instead of failing.
expected fix: when "-c" is used without a value, it should use the default value "1". When "-c" is given a bad value, it should fail and show an error message.

- [ ] we must make safer type checking for options and arguments, and must only execute a command if all required arguments and options are provided and valid. Currenly, invalid arguments are silently:
PS E:\Code\NimmeurDuDimanche\nimancer\examples> .\basic_cli.exe more-complex rezrz
A very complex command

- [ ] we should extend our test suite to cover more edge cases and error scenarios (e.g. invalid types, missing required args, too many args, args provided where no expected, etc.)


Check examples and run them with:
```bash
nim c -r --path:src examples/todo.nim # (or examples/basic_cli.nim)
```
