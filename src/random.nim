# Copyright (C) 2014-2015 Oleh Prypin <blaxpirit@gmail.com>
# 
# This file is part of nim-random.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


## This module is just a convenience import. It exports `random.mersenne` and
## `random.urandom` and defines a global instance of Mersenne twister with
## alias procedures that use this instance.


import times
import random.mersenne, random.urandom
export mersenne, urandom


var mersenneTwisterInst*: MersenneTwister
  ## A global instance of Mersenne twister used by the alias functions.
  ##
  ## When the module is imported, it is seeded using an array of bytes provided
  ## by ``urandom``, or, in case of failure, using the current time.
  ##
  ## Due to this silent fallback and the fact that any other code can use this
  ## global instance (and there is no thread safety), it is not recommended to
  ## use it (through the functions in this module or otherwise) if you have any
  ## concerns for security.

proc seedImpl(self: var MersenneTwister) {.inline.} =
  try:
    self = initMersenneTwister(urandom(2500))
  except OSError:
    self = initMersenneTwister(uint32(uint(epochTime()*256)))

mersenneTwisterInst.seedImpl()


proc randomByte*(): uint8 {.inline.} =
  ## Alias to MT
  mersenneTwisterInst.randomByte()
proc random*(): float64 {.inline.} =
  ## Alias to MT
  mersenneTwisterInst.random()
proc random*(max: float): float {.inline.} =
  ## Alias to MT
  mersenneTwisterInst.random(max)
proc random*(min, max: float): float {.inline.} =
  ## Alias to MT
  mersenneTwisterInst.random(min, max)
proc randomInt*(max: uint): uint {.inline.} =
  ## Alias to MT
  mersenneTwisterInst.randomInt(max)
proc randomInt*(max: Positive): Natural {.inline.} =
  ## Alias to MT
  mersenneTwisterInst.randomInt(max)
proc randomInt*(min, max: int): int {.inline.} =
  ## Alias to MT
  mersenneTwisterInst.randomInt(min, max)
proc randomInt*(slice: Slice[int]): int {.inline.} =
  ## Alias to MT
  mersenneTwisterInst.randomInt(slice)
proc randomBool*(): bool {.inline.} =
  ## Alias to MT
  mersenneTwisterInst.randomBool()
proc randomChoice*[T](arr: T): auto {.inline.} =
  ## Alias to MT
  mersenneTwisterInst.randomChoice(arr)
proc shuffle*[T](arr: var T) {.inline.} =
  ## Alias to MT
  mersenneTwisterInst.shuffle(arr)
iterator randomSample*[T](arr: T, n: Natural): auto {.inline.} =
  ## Alias to MT
  for x in mersenneTwisterInst.randomSample(arr, n):
    yield x


proc seed*(self: var MersenneTwister) {.deprecated.} =
  ## Seeds (randomizes) using an array of bytes provided by ``urandom``, or,
  ## in case of failure, using the current time (with resolution of 1/256 sec).
  ## 
  ## *Deprecated*: Seed with ``urandom(2500)`` explicitly instead.
  self.seedImpl()
