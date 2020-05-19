import strformat
# Package

version       = "0.1.0"
author        = "luxick"
description   = "Play an image slide show from different sources"
license       = "GPL-2.0"
srcDir        = "src"
bin           = @["randopix", "pixctrl"]

# Dependencies
requires "nim >= 1.0.0", "gintro >= 0.5.5", "argparse >=0.10.1"

task debug, "Compile debug version":
  exec "nim c -d:debug --debugger:native src/randopix.nim"

task release, "Compile release version":
  exec fmt"nim c -d:release --out:randopix-{version} src/randopix.nim"
