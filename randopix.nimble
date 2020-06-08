# Package

version       = "0.2.0"
author        = "luxick"
description   = "Play an image slide show from different sources"
license       = "GPL-2.0"
srcDir        = "src"
binDir        = "bin"
bin           = @["randopix", "pixctrl"]

# Dependencies
requires "nim >= 1.0.0", "gintro", "argparse", "jester", "ajax"

proc genJS =
  echo "Generating JS Client"
  exec("nim js -o:src/resources/pixctrl.js src/pixctrl.nim")

task genJS, "Generate the Javascript client":
  genJS()

task buildAll, "Generate JS and run build":
  genJS()
  exec "nimble build"

task debug, "Compile debug version":
  exec "nim c -d:debug --debugger:native -o:bin/randopix src/randopix.nim"

before install:
  genJS()