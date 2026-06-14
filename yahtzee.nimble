# Package
version       = "0.1.0"
author        = "pietroP"
description   = "Client-only Yahtzee game in Nim + Karax"
license       = "MIT"
srcDir        = "src"

# Dependencies
requires "nim >= 1.6.0"
requires "karax >= 1.3.0"

task build, "Compile to JS":
  exec "nim js -d:release --path:/root/.nimble/pkgs/karax-1.5.0 -o:app.js src/yahtzee.nim"
