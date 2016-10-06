# Copyright (C) 2014-2016 Oleh Prypin <blaxpirit@gmail.com>
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

import intsets
import private/util, private/random_real


type RNG8 = concept var rng
  rng.randomUint8() is uint8
type RNG32 = concept var rng
  rng.randomUint32() is uint32
type RNG64 = concept var rng
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
  let neededParts = sizeof(T) div sizeof(rng.baseType)

  # Build up the number combining multiple outputs from the RNG. See comments below.
  result = cast[T](rng.baseRandom)
  for i in 2..neededParts:
    result = (result shl (sizeof(rng.baseType)*8)) or cast[T](rng.baseRandom())

proc randomInt*(rng: var RNG; T: typedesc[SomeInteger]): T {.inline.} =
  ## Returns a uniformly distributed random integer ``T.low <= x <= T.high``
  randomIntImpl[T, RNG](rng)

template high(T: typedesc[SomeInteger]): untyped =
  when T is uint64:
    0xffffffffffffffff'u64
  elif T is int64:
    0x7fffffffffffffff'i64
  else:
    system.high(T)

proc randomInt*[T: SomeInteger](rng: var RNG; max: T): T =
  ## Returns a uniformly distributed random integer ``0 <= x < max``
  if max <= 0:
    raise newException(ValueError, "randomInt bound must be > 0")

  # The basic ideas of the algorithm are best illustrated with examples.
  #
  # Let's say we have a random number generator that gives uniformly distributed random numbers
  # between 0 and 15. We need to get a uniformly distributed random number between 0 and 5
  # (`max` = 6). The typical mistake made in this case is to just use ``rand() mod 6``, but it is
  # clear that some results will appear more often than others. So, the surefire approach is to make
  # the RNG spit out numbers until it gives one inside our desired range. That is really wasteful
  # though. So the approach taken here is to discard only a small range of the possible generated
  # numbers, and use the modulo operation on the "valid" ones, like this (where X means "discard and
  # try again"):
  #
  # Generated number:  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
  #           Result:  0  1  2  3  4  5  0  1  2  3  4  5  X  X  X  X
  #
  # 12 is the `limit` here - the highest number divisible by `max` while still being within bounds
  # of what the RNG can produce.
  #
  # On the other side of the spectrum is the problem of generating a random number in a higher range
  # than what the RNG can produce. Let's say we have the same mentioned RNG, but we need a uniformly
  # distributed random number between 0 and 255. All that needs to be done is to generate two random
  # numbers between 0 and 15, and combine their bits (i.e. ``rand()*16 + rand()``).
  #
  # Using a combination of these tricks, any RNG can be turned into any RNG, however, there are
  # several difficult parts about this. The code below uses as few calls to the underlying RNG as
  # possible, meaning that (with the above example) with `max` being 257, it would call the RNG 3
  # times. (Of course, it doesn't actually deal with RNGs that produce numbers 0 to 15, only with
  # the `uint8`, `uint32` and `uint64` ranges.
  #
  # Another problem is how to actually compute the `limit`. The obvious way to do it, which is
  # ``(RAND_MAX + 1) div max * max``, fails because `RAND_MAX` is usually already the highest number
  # that an integer type can hold. And even the `limit` itself will often be ``RAND_MAX + 1``,
  # meaning that we don't have to discard anything. The ways to deal with this are described below.

  if cast[uint64](max - 1) <= cast[uint64](high(rng.baseType)):
    # One number from the RNG will be enough.
    # All the computations will (almost) fit into `rng.baseType`.

    # Relies on integer overflow + wraparound to find the highest number divisible by `max`.
    let limit = cast[rng.baseType](0) -
      (cast[rng.baseType](0) - cast[rng.baseType](max)) mod cast[rng.baseType](max)
    # `limit` might be 0, which means it would've been ``high(rng.baseType) + 1``, but didn't fit
    # into the integer type.

    while true:
      let rand = rng.baseRandom()

      # For a uniform distribution we may need to throw away some numbers
      if rand < limit or limit == 0:
        return cast[T](rand mod cast[rng.baseType](max))

  else:
    # We need to find out how many random numbers need to be combined to be able to generate a
    # random number of this magnitude. All the computations will be based on `T` as the larger type.

    # ``randMax - 1`` is the maximal number we can get from combining `neededParts` random numbers.
    # Compute `randMax` as ``pow(high(rng.baseType) + 1, neededParts)``.
    # If `randMax` becomes 0, that means it has reached ``high(T) + 1``.
    var randMax = T(1) shl (sizeof(rng.baseType)*8)
    var neededParts = 1
    while randMax < max and randMax > T(0):
      randMax = randMax shl (sizeof(rng.baseType)*8)
      neededParts += 1

    let limit =
      if randMax > T(0):
        # `randMax` didn't overflow, so we can calculate the `limit` the straightforward way.
        randMax div max * max
      else:
        # `randMax` is ``high(T) + 1``, need the same wraparound trick. `limit` might become 0,
        # which means it would've been ``high(T) + 1``, but didn't fit into the integer type.
        T(0) - (T(0) - max) mod max

    while true:
      # Build up the number combining multiple outputs from the RNG.
      var rand = cast[T](rng.baseRandom())
      for i in 2..neededParts:
        rand = (rand shl (sizeof(rng.baseType)*8)) or cast[T](rng.baseRandom())

      # For a uniform distribution we may need to throw away some numbers.
      if rand < limit or limit == 0:
        return rand mod max

proc randomInt*(rng: var RNG; min, max: int): int {.inline.} =
  ## Returns a uniformly distributed random integer ``min <= x < max``
  min + rng.randomInt(max - min)

proc randomInt*(rng: var RNG; interval: Slice[int]): int {.inline.} =
  ## Returns a uniformly distributed random integer ``interval.a <= x <= interval.b``
  interval.a + rng.randomInt(interval.b - interval.a + 1)

proc randomBool*(rng: var RNG): bool {.inline.} =
  ## Returns a random boolean
  bool(rng.randomInt(2))


#: Random Reals

proc random*(rng: var RNG): float64 =
  ## Returns a uniformly distributed random number ``0 <= x < 1``
  const maxPrec = 1u64 shl 53 # float64, excluding mantissa, has 2^53 values
  float64(rng.randomInt(maxPrec))/float64(maxPrec)

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
  ## Randomly shuffles elements of a random access container.
  # Fisher-Yates shuffle
  for i in arr.low..arr.high:
    let j = rng.randomInt(i..arr.high)
    swap arr[j], arr[i]


iterator randomSample*(rng: var RNG; interval: Slice[int]; n: Natural): int =
  ## Yields `n` random integers ``interval.a <= x <= interval.b`` in random order.
  ## Each number has an equal chance to be picked and can be picked only once.
  ##
  ## Raises ``ValueError`` if there are less than `n` items in `interval`.
  if n > interval.b - interval.a + 1:
    raise newException(ValueError, "Sample can't be larger than population")
  # Simple random sample
  var iset = initIntSet()
  var remaining = n
  while remaining > 0:
    let x = rng.randomInt(interval)
    if not containsOrIncl(iset, x):
      yield x
      dec remaining

iterator randomSample*(rng: var RNG; arr: RAContainer; n: Natural): auto =
  ## Yields `n` items randomly picked from a random access container `arr`,
  ## in random order. Each item has an equal chance to be picked
  ## and can be picked only once. Duplicate items are allowed in `arr`,
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
  if n == 0:
    return
  for r in result.mitems:
    r = iter()
    if iter.finished:
      raise newException(ValueError, "Sample can't be larger than population")
  var idx = n
  for e in iter():
    let r = rng.randomInt(0..idx)
    if r < n:
      result[r] = e
    inc idx


when defined(test):
  import unittest, sequtils, tables
  import xorshift, private/testutil

  var dataRNG8 = [234u8, 153, 0, 0, 127, 128, 255, 255]
  type TestRNG8 = object
    n: int
  proc randomUint8(rng: var TestRNG8): uint8 =
    result = dataRNG8[rng.n]
    rng.n = (rng.n+1) mod dataRNG8.len
  var testRNG8: TestRNG8

  var dataRNG32 = [31541451u32, 0, 1, 234, 342475672, 863, 0xffffffffu32, 50967465]
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

  proc clItems[T](s: seq[T]): auto =
    (iterator(): T =
      for x in s: yield x)

  suite "Common":
    echo "Common:"

    test "randomInt(T) accumulation":
      testRNG8 = TestRNG8()
      for i in 0..3:
        let result = randomInt(testRNG8, uint16)
        let expected = uint16(dataRNG8[i*2])*0x100u16 + uint16(dataRNG8[i*2+1])
        check result == expected

    test "randomInt(T) truncation":
      testRNG32 = TestRNG32()
      for i in 0..7:
        let result = randomInt(testRNG32, uint16)
        let expected = dataRNG32[i] mod 0x10000u32
        check uint32(result) == expected

    test "randomInt(T) negation":
      testRNG8 = TestRNG8()
      for i in 0..7:
        let result = randomInt(testRNG8, int8)
        if dataRNG8[i] > 0x80u8:
          let expected = int(dataRNG8[i]) - 0x100
          check int(result) == expected

    test "randomInt(max) accumulation":
      testRNG8 = TestRNG8()
      check randomInt(testRNG8, 65536) == 60057 # 234*0x100 + 153
      check randomInt(testRNG8, 60000) == 0     # 0*0x100 + 0
      check randomInt(testRNG8, 30000) == 2640  # (127*0x100 + 128) mod 30000
      check randomInt(testRNG8, 65535) == 60057 # 255*0x100 + 255 [skip]-> 234*0x100 + 153
      testRNG8 = TestRNG8()
      check randomInt(testRNG8, 65537) == 38934 # (234*0x10000 + 153*0x100 + 0) mod 65537

    test "randomInt(max) truncation":
      testRNG32 = TestRNG32()
      check randomInt(testRNG32, 1) == 0
      check randomInt(testRNG32, 10) == 0
      check randomInt(testRNG32, 2) == 1

    test "random chiSquare":
      for seed in xorshift.seeds:
        var rng = initXorshift128Plus(seed)
        proc rand(): float = rng.random()
        let r = chiSquare(rand, bucketCount = 100, experiments = 100000)
        # Probability less than the critical value, v = 99
        #    0.90      0.95     0.975      0.99     0.999
        # 117.407   123.225   128.422   134.642   148.230
        check r < 128.422

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

    test "randomPrecise chiSquare":
      for seed in xorshift.seeds:
        var rng = initXorshift128Plus(seed)
        proc rand(): float = rng.randomPrecise()
        let r = chiSquare(rand, bucketCount = 100, experiments = 100000)
        # Probability less than the critical value, v = 99
        #    0.90      0.95     0.975      0.99     0.999
        # 117.407   123.225   128.422   134.642   148.230
        check r < 134.642

    test "shuffle chiSquare":
      for seed in xorshift.seeds:
        var rng = initXorshift128Plus(seed)
        proc rand(): seq[int] =
          result = toSeq(1..4)
          rng.shuffle(result)
        # 4! = 24
        let r = chiSquare(rand, bucketCount = 24, experiments = 100000)
        # Probability less than the critical value, v = 23
        #    0.90      0.95     0.975      0.99     0.999
        #  32.007    35.172    38.076    41.638    49.728
        check r < 41.638

    test "randomSample":
      var rng = initXorshift128Plus(123)
      expect ValueError:
        for x in rng.randomSample(7..7, 2):
          discard

      let z = toSeq(rng.randomSample(7..20, 0))
      check z == newSeq[int]()

      for seed in xorshift.seeds:
        rng = initXorshift128Plus(seed)
        for i in 1..100:
          var a = rng.randomInt(1..2000)
          var b = rng.randomInt(1..2000)
          if a > b: swap a, b
          let n = rng.randomInt(0 .. b-a+1)
          let s = toSeq(rng.randomSample(a..b, n))
          check s.len == n
          check s.deduplicate().len == n

    test "randomSample chiSquare":
      for seed in xorshift.seeds:
        var rng = initXorshift128Plus(seed)
        proc rand(): seq[int] = toSeq(rng.randomSample(1..5, 3))
        # A(5, 3) = 60
        let r = chiSquare(rand, bucketCount = 60, experiments = 100000)
        # Probability less than the critical value, v = 59
        #    0.90      0.95     0.975      0.99     0.999
        #  73.279    77.931    82.117    87.166    98.324
        check r < 87.166

    test "randomSample reservoir":
      var rng = initXorshift128Plus(123)
      expect ValueError:
        for x in rng.randomSample(@[7].clItems, 2):
          discard

      let z = rng.randomSample(@[7, 8, 9].clItems, 0)
      check z == newSeq[int]()

      for seed in xorshift.seeds:
        rng = initXorshift128Plus(seed)
        for i in 1..100:
          var a = rng.randomInt(1..2000)
          var b = rng.randomInt(1..2000)
          if a > b: swap a, b
          let n = rng.randomInt(0 .. b-a+1)
          let s = rng.randomSample(toSeq(a..b).clItems, n)
          check s.len == n
          check s.deduplicate().len == n

    test "randomSample reservoir chiSquare":
      for seed in xorshift.seeds:
        var rng = initXorshift128Plus(seed)
        proc rand(): set[1..8] =
          for e in rng.randomSample(toSeq(1..8).clItems, 3):
            result.incl e
        # C(8, 3) = 56
        let r = chiSquare(rand, bucketCount = 56, experiments = 100000)
        # Probability less than the critical value, v = 55
        #    0.90      0.95     0.975      0.99     0.999
        #  68.796    73.311    77.380    82.292    93.168
        check r < 82.292
