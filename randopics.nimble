import strformat
# Package

version       = "0.1.0"
author        = "luxick"
description   = "Play an image slide show from different sources"
license       = "GPL-2.0"
srcDir        = "src"
bin           = @["randopics"]

# Dependencies
requires "nim >= 1.0.0", "gintro <= 0.5.5"

task debug, "Compile debug version":
  exec "nim c --out:bin/randopics src/randopics.nim"

task release, "Compile release version":
  exec fmt"nim c -d:release --out:bin/{version}/randopics src/randopics.nim"
