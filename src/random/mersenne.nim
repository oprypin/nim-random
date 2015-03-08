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
import common, private/util
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

proc initMersenneTwister*(seed: openArray[uint8]): MersenneTwister =
  let words = bytesToWords[uint32](seed)
  initMersenneTwister(words)
# Seeds a new ``MersenneTwister`` with an array of bytes

proc initMersenneTwister*(seed: uint32): MersenneTwister =
  ## Seeds a new ``MersenneTwister`` with an ``uint32``
  result = initMTState()
  result.initGenrand(seed)


when defined(test):
  import unittest
  import private/testutil
  
  const seeds = [
    47845723665u32, 2536452432u32, 1u32, 0u32, 239463294u32, 2466576764u32, 12359836u32, 243573567567u32, 2452567348u32, 0xffffffffu32, 3987349243u32, 983991231u32, 234234u32, 9199139u32, 424553u32, 234642342u32, 123836u32
  ]
  
  suite "Mersenne Twister":
    echo "Mersenne Twister:"
    
    test "implementation":
      var rng = initMersenneTwister([0x123u32, 0x234, 0x345, 0x456])
      check([rng.randomUint32(), rng.randomUint32(), rng.randomUint32()] == [
        1067595299u32, 955945823, 477289528
      ])

    test "chiSquare":
      var rs = newSeq[float]()
      for seed in seeds:
        var rng = initMersenneTwister(seed)
        proc rand(): int = rng.randomInt(100)
        let r = chiSquare(rand, bucketCount = 100, experiments = 1000000)
        rs.add(r)
        # Probability less than the critical value, v = 99
        #    0.90      0.95     0.975      0.99     0.999
        # 117.407   123.225   128.422   134.642   148.230
        check r < 123.225
      check average(rs) < 117.407
