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


## This module is exported by all other modules. It defines common operations
## that work for all the PRNGs provided by this library.

import intsets, unsigned
import private/util, private/random_real


type RNG8 = generic var rng
  rng.randomUint8() is uint8
type RNG32 = generic var rng
  rng.randomUint32() is uint32
type RNG64 = generic var rng
  rng.randomUint64() is uint64
type RNG* = RNG8 or RNG32 or RNG64
  ## Random number generator

template baseType(rng): expr =
  when compiles(rng.randomUint32()): uint32
  elif compiles(rng.randomUint64()): uint64
  elif compiles(rng.randomUint8()): uint8
  else:
    assert false
    uint32

template baseRandom(rng): expr =
  when compiles(rng.randomUint32()): rng.randomUint32()
  elif compiles(rng.randomUint64()): rng.randomUint64()
  elif compiles(rng.randomUint8()): rng.randomUint8()
  else:
    assert false
    0u32


#: Random Integers

proc randomIntImpl[T: SomeInteger; RNG](rng: var RNG): T =
  when sizeof(T) <= sizeof(rng.baseType):
    cast[T](rng.baseRandom())
  else:
    let neededParts = sizeof(T) div sizeof(rng.baseType)
    for i in 1..neededParts:
      result = (result shl T(sizeof(rng.baseType)*8)) or
        cast[T](rng.baseRandom())

proc randomInt*(rng: var RNG; T: typedesc[SomeInteger]): T {.inline.} =
  ## Returns a uniformly distributed random integer ``T.low <= x <= T.high``
  randomIntImpl[T, RNG](rng)

proc randomByte*(rng: var RNG): uint8 {.inline, deprecated.} =
  ## Returns a uniformly distributed random integer ``0 <= x < 256``
  ## 
  ## *Deprecated*: Use ``randomInt(uint8)`` instead.
  rng.randomInt(uint8)

const intLimit = uint(int.high)+1u

proc randomIntImpl(rng: var RNG; max: uint): uint =
  # We're assuming 0 < max <= int.high
  let limit = intLimit - intLimit mod max
  # uint64.high doesn't work...
  when compiles(rng.baseType.high):
    if max <= rng.baseType.high:
      while true:
        result = cast[uint](rng.baseRandom())
        if result < limit: break
    else:
      let neededParts = divCeil(bitSize(max), sizeof(rng.baseType)*8)
      while true:
        for i in 1..neededParts:
          result = (result shl (sizeof(rng.baseType)*8)) or rng.baseRandom()
        if result < limit: break
  else:
    while true:
      result = cast[uint](rng.baseRandom())
      if result < limit: break
  result = result mod max

proc randomInt*(rng: var RNG; max: Positive): Natural {.inline.} =
  ## Returns a uniformly distributed random integer ``0 <= x < max``
  rng.randomIntImpl(uint(max))

proc randomInt*(rng: var RNG; min, max: int): int {.inline.} =
  ## Returns a uniformly distributed random integer ``min <= x < max``
  min + rng.randomInt(max - min)

proc randomInt*(rng: var RNG; range: Slice[int]): int {.inline.} =
  ## Returns a uniformly distributed random integer ``range.a <= x <= range.b``
  range.a + rng.randomInt(range.b - range.a + 1)

proc randomBool*(rng: var RNG): bool {.inline.} =
  ## Returns a random boolean
  bool(rng.randomInt(2))


#: Random Reals

proc random*(rng: var RNG): float64 =
  ## Returns a uniformly distributed random number ``0 <= x < 1``
  const maxPrec = 1 shl 53 # float64, excluding mantissa, has 2^53 values
  float64(rng.randomInt(maxPrec))/maxPrec

proc random*(rng: var RNG; max: float): float {.inline.} =
  ## Returns a uniformly distributed random number ``0 <= x < max``
  max*rng.random()

proc random*(rng: var RNG; min, max: float): float {.inline.} =
  ## Returns a uniformly distributed random number ``min <= x < max``
  min+(max-min)*rng.random()

proc randomPrecise*(rng: var RNG): float64 =
  ## Returns a uniformly distributed random number ``0 <= x <= 1``,
  ## with more resolution (doesn't skip values).
  ## 
  ## Based on http://mumble.net/~campbell/2014/04/28/uniform-random-float
  random_real.randomReal(rng.randomInt(uint64))


#: Sequence Operations

proc randomChoice*(rng: var RNG; arr: RAContainer): auto {.inline.} =
  ## Selects a random element (all of them have an equal chance)
  ## from a random access container and returns it
  arr[rng.randomInt(arr.low..arr.high)]


proc shuffle*(rng: var RNG; arr: var RAContainer) =
  ## Fisher-Yates shuffle.
  ## 
  ## Randomly shuffles elements of a random access container.
  for i in arr.low..arr.high:
    let j = rng.randomInt(i..arr.high)
    swap arr[j], arr[i]


iterator randomSample*(rng: var RNG; range: Slice[int]; n: Natural): int =
  ## Simple random sample.
  ## 
  ## Yields `n` random integers ``range.a <= x <= range.b`` in ascending order.
  ## Each number has an equal chance to be picked and can be picked only once.
  ## 
  ## Raises ``ValueError`` if there are less than `n` items in `range`.
  let count = range.b - range.a + 1
  if n > count:
    raise newException(ValueError, "Sample can't be larger than population")
  let direct = (n <= (count div 2)+10)
  # "direct" means we will be filling the set with items to include
  # "not direct" means filling it with items to exclude
  var remaining = if direct: n else: count-n
  var iset = initIntSet()
  while remaining > 0:
    let x = rng.randomInt(range)
    if not containsOrIncl(iset, x):
      dec remaining
  #if direct:
  for i in iset.items():
    yield i
  #else:
    #for i in missingItems(iset, range):
      #yield i

iterator randomSample*(rng: var RNG; arr: RAContainer; n: Natural): auto =
  ## Simple random sample.
  ## 
  ## Yields `n` items randomly picked from a random access container `arr`,
  ## in the relative order they were in it. Each item has an equal chance to be
  ## picked and can be picked only once. Duplicate items are allowed in `arr`,
  ## and they will not be treated in any special way.
  ## 
  ## Raises ``ValueError`` if there are less than `n` items in `arr`.
  for i in rng.randomSample(arr.low..arr.high, n):
    yield arr[i]

proc randomSample*[T](rng: var RNG; iter: iterator(): T; n: Natural): seq[T] =
  ## Random sample using reservoir sampling algorithm.
  ## 
  ## Returns a sequence of `n` items randomly picked from an iterator `iter`,
  ## in no particular order. Each item has an equal chance to be picked and can
  ## be picked only once. Repeating items are allowed in `iter`, and they will
  ## not be treated in any special way.
  ## 
  ## Raises ``ValueError`` if there are less than `n` items in `iter`.
  result = newSeq[T](n)
  for r in result.mitems:
    if iter.finished:
      raise newException(ValueError, "Sample can't be larger than population")
    r = iter()
  var idx = result.len
  for e in iter():
    let r = rng.randomInt(idx)
    if r < n:
      result[r] = e
    inc idx



when defined(test):
  import unittest
  import xorshift
  
  var dataRNG8 = [234u8, 153, 0, 0, 127, 128, 255, 255]
  type TestRNG8 = object
    n: int
  proc randomUint8(rng: var TestRNG8): uint8 =
    result = dataRNG8[rng.n]
    rng.n = (rng.n+1) mod dataRNG8.len
  var testRNG8: TestRNG8
  
  var dataRNG32 = [31541451u32, 0, 1, 234, 342475672, 863, 0xffffffff, 50967465]
  type TestRNG32 = object
    n: int
  proc randomUint32(rng: var TestRNG32): uint32 =
    result = dataRNG32[rng.n]
    rng.n = (rng.n+1) mod dataRNG32.len
  var testRNG32: TestRNG32
  
  var dataRNG64 = [148763248732657823u64, 18446744073709551615u64, 0u64,
    32456325635673576u64, 2456245614625u64, 32452456246u64, 3956529762u64,
    9823674982364u64, 234253464546456u64, 14345435645646u64]
  type TestRNG64 = object
    n: int
  proc randomUint64(rng: var TestRNG64): uint64 =
    result = dataRNG64[rng.n]
    rng.n = (rng.n+1) mod dataRNG64.len
  var testRNG64: TestRNG64
  
  suite "Common":
    echo "Common:"

    test "randomInt(T) accumulation":
      testRNG8 = TestRNG8()
      for i in 0..3:
        let result = randomInt(testRNG8, uint16)
        let expected = int(dataRNG8[i*2])*0x100 + int(dataRNG8[i*2+1])
        check int(result) == expected
    
    test "randomInt(T) truncation":
      testRNG32 = TestRNG32()
      for i in 0..7:
        let result = randomInt(testRNG32, uint16)
        let expected = int(dataRNG32[i]) mod 0x10000
        check int(result) == expected
    
    test "randomInt(T) negation":
      testRNG8 = TestRNG8()
      for i in 0..7:
        let result = randomInt(testRNG8, int8)
        if dataRNG8[i] > 0x80u8:
          let expected = int(dataRNG8[i]) - 0x100
          check int(result) == expected

    test "randomPrecise implementation":
      testRNG64 = TestRNG64()
      for bounds in [
        (0.0080644e-00 .. 0.0080645e-00),
        (9.5380568e-23 .. 9.5380569e-23),
        (1.7592511e-09 .. 1.7592512e-09),
        (5.3254248e-07 .. 5.3254249e-07),
        (7.7766762e-07 .. 7.7766763e-07),
        (0.9999999e-00 .. 1.0000001e-00),
        (9.5380568e-23 .. 9.5380569e-23),
        (1.7592511e-09 .. 1.7592512e-09),
        (5.3254248e-07 .. 5.3254249e-07),
        (7.7766762e-07 .. 7.7766763e-07),
        (0.9999999e-00 .. 1.0000001e-00),
        (9.5380568e-23 .. 9.5380569e-23),
      ]:
        let r = float(testRNG64.randomPrecise())
        check bounds.a < r and r < bounds.b
