import strformat
# Package

version       = "0.1.0"
author        = "luxick"
description   = "Play an image slide show from different sources"
license       = "GPL-2.0"
srcDir        = "src"
binDir        = "bin"
bin           = @["randopix", "pixctrl"]

# Dependencies
requires "nim >= 1.0.0", "gintro", "argparse", "jester"

task genJS, "Generate the Javascript client":
  exec "nim js -o:src/resources/script.js src/pixscript.nim"

task debug, "Compile debug version":
  exec "nim c -d:debug --debugger:native -o:bin/randopix src/randopix.nim"

task release, "Compile release version":
  exec fmt"nim c -d:release -o:bin/randopix-{version} src/randopix.nim"
