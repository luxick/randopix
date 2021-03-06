# Package

version       = "1.1.0"
author        = "luxick"
description   = "Play an image slide show from different sources"
license       = "GPL-2.0"
srcDir        = "src"
binDir        = "bin"
bin           = @["randopix", "pixctrl"]

# Dependencies
requires "nim >= 1.0.0", "gintro", "argparse", "jester", "ajax"
# Not on nimble yet
requires "https://github.com/luxick/op.git >= 1.0.0"

proc genJS =
  echo "Generating JS Client"
  exec("nim js -o:src/resources/www/pixctrl.js src/pixctrl.nim")

task genJS, "Generate the Javascript client":
  genJS()

task buildAll, "Generate JS and run build":
  genJS()
  exec "nimble build"

task debug, "Compile debug version":
  exec "nim c -d:debug --debugger:native -o:bin/randopix src/randopix.nim"

before install:
  genJS()