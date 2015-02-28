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


import unsigned
import common, private/seeding
import private/mt19937ar
export common


type MersenneTwister* = MTState
  ## Mersenne Twister (MT19937). Based on
  ## http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/MT2002/emt19937ar.html

proc randomUint32*(self: var MersenneTwister): uint32 {.inline.} =
  self.genrandInt32()

proc random*(self: var MersenneTwister): float64 {.inline.} =
  self.genrandRes53()

proc initMersenneTwister*(seed: openArray[uint32]): MersenneTwister =
  ## Seeds a new ``MersenneTwister`` with an array of ``uint32``
  result = initMTState()
  result.initByArray(seed)

makeBytesSeeding(MersenneTwister, uint32)

proc initMersenneTwister*(seed: uint32): MersenneTwister =
  ## Seeds a new ``MersenneTwister`` with an ``uint32``
  result = initMTState()
  result.initGenrand(seed)


proc seed*(self: var MersenneTwister, s: openArray[uint8]) {.deprecated.} =
  ## *Deprecated*: Use ``initMersenneTwister`` instead.
  self = initMersenneTwister(s)

proc seed*(self: var MersenneTwister, s: int) {.deprecated.} =
  ## *Deprecated*: Use ``initMersenneTwister`` instead.
  self = initMersenneTwister(uint32(s))

proc initMersenneTwister*(): MersenneTwister {.deprecated.} =
  ## Initializes and returns a new MersenneTwister 
  ## 
  ## *Deprecated*: Initialize with a seed instead.
  initMTState()

{.deprecated: [TMersenneTwister: MersenneTwister].}


when defined(test):
  import unittest
  
  suite "Mersenne Twister":
    echo "Mersenne Twister:"
    
    test "implementation":
      var rng = initMersenneTwister([0x123u32, 0x234, 0x345, 0x456])
      check([rng.randomUint32(), rng.randomUint32(), rng.randomUint32()] == [
        1067595299u32, 955945823, 477289528
      ])
