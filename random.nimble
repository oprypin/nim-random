packageName   = "random"
version       = "0.5.7"
author        = "Oleh Prypin"
description   = "Pseudo-random number generation library inspired by Python"
license       = "MIT"
srcDir        = "src"
skipDirs      = @["test"]

requires "nim >= 0.12.0"

task test, "test nim-random":
  --define: test
  --run
  setCommand "c", "test/test.nim"
