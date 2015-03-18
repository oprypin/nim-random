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
import random/private/util
export mersenne, urandom


var mersenneTwisterInst*: MersenneTwister
  ## A global instance of Mersenne twister used by the alias functions of this
  ## module.
  ##
  ## When the module is imported, it is seeded using an array of bytes provided
  ## by ``urandom``, or, in case of failure, using the current time.
  ##
  ## Due to this silent fallback and the fact that any other code can use this
  ## global instance (and there is no thread safety), it is not recommended to
  ## use it (through the functions in this module or otherwise) if you have any
  ## concerns for security.

try:
  mersenneTwisterInst = initMersenneTwister(urandom(2500))
except OSError:
  mersenneTwisterInst = initMersenneTwister(uint32(uint(epochTime()*256)))


proc randomInt*(T: typedesc): T {.inline.} =
  mersenneTwisterInst.randomInt(T)
proc randomByte*(): uint8 {.inline, deprecated.} =
  ## *Deprecated*: Use ``randomInt(uint8)`` instead.
  mersenneTwisterInst.randomInt(uint8)

proc randomInt*(max: Positive): Natural {.inline.} =
  mersenneTwisterInst.randomInt(max)
proc randomInt*(min, max: int): int {.inline.} =
  mersenneTwisterInst.randomInt(min, max)
proc randomInt*(slice: Slice[int]): int {.inline.} =
  mersenneTwisterInst.randomInt(slice)
proc randomBool*(): bool {.inline.} =
  mersenneTwisterInst.randomBool()

proc random*(): float64 {.inline.} =
  mersenneTwisterInst.random()
proc random*(max: float): float {.inline.} =
  mersenneTwisterInst.random(max)
proc random*(min, max: float): float {.inline.} =
  mersenneTwisterInst.random(min, max)
proc randomPrecise*(): float64 {.inline.} =
  mersenneTwisterInst.randomPrecise()

proc randomChoice*(arr: RAContainer): auto {.inline.} =
  mersenneTwisterInst.randomChoice(arr)

proc shuffle*(arr: var RAContainer) {.inline.} =
  mersenneTwisterInst.shuffle(arr)

iterator randomSample*(arr: RAContainer; n: Natural): auto {.inline.} =
  for x in mersenneTwisterInst.randomSample(arr, n):
    yield x
proc randomSample*[T](iter: iterator(): T; n: Natural): seq[T] {.inline.} =
  mersenneTwisterInst.randomSample(iter, n)
