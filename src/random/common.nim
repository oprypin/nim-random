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
import private/util


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
    0'u32


proc randomInt[T: SomeInteger](rng: var RNG): T =
  when sizeof(T) <= sizeof(rng.baseType):
    cast[T](rng.baseRandom())
  else:
    let neededParts = sizeof(T) div sizeof(rng.baseType)
    for i in 1..neededParts:
      result = (result shl T(sizeof(rng.baseType)*8)) or
        cast[T](rng.baseRandom())

proc randomInt*(rng: var RNG, T: typedesc): T {.inline.} =
  ## Returns a uniformly distributed random integer ``T.low <= n <= T.high``
  randomInt[T](rng)

proc randomByte*(rng: var RNG): uint8 {.inline, deprecated.} =
  ## Returns a uniformly distributed random integer ``0 <= n < 256``
  ## 
  ## *Deprecated*: Use ``randomInt(uint8)`` instead.
  rng.randomInt(uint8)


proc randomInt*(rng: var RNG; max: uint): uint =
  ## Returns a uniformly distributed random integer ``0 <= n < max``
  var mask = uint(max)
  # The mask will be the closest power of 2 minus one
  # It has the same number of bits as `max`, but consists only of 1-bits
  for i in 0..5: # 1, 2, 4, 8, 16, 32
    mask = mask or (mask shr uint(1 shl i))
  if max <= rng.baseType.high:
    while true:
      result = cast[uint](rng.baseRandom()) and mask
      if result < max: break
  else:
    let neededParts = divCeil(byteSize(max), sizeof(rng.baseType))
    while true:
      for i in 1..neededParts:
        result = (result shl (sizeof(rng.baseType)*8)) or rng.baseRandom()
      result = result and mask
      if result < max: break

proc randomInt*(rng: var RNG; max: Positive): Natural {.inline.} =
  ## Returns a uniformly distributed random integer ``0 <= n < max``
  rng.randomInt(uint(max))



proc random*(rng: var RNG): float64 =
  ## Returns a uniformly distributed random number ``0 <= n < 1``
  const MAX_PREC = 1 shl 53 # float64, excluding mantissa, has 2^53 values
  return float64(rng.randomInt(MAX_PREC))/MAX_PREC

proc randomInt*(rng: var RNG; min, max: int): int =
  ## Returns a uniformly distributed random integer ``min <= n < max``
  min+rng.randomInt(max-min)

proc randomInt*(rng: var RNG; slice: Slice[int]): int {.inline.} =
  ## Returns a uniformly distributed random integer ``slice.a <= n <= slice.b``
  rng.randomInt(slice.a, slice.b+1)

proc randomBool*(rng: var RNG): bool {.inline.} =
  ## Returns a random boolean
  bool(rng.randomInt(2))


proc random*(rng: var RNG; min, max: float): float =
  ## Returns a uniformly distributed random number ``min <= n < max``
  min+(max-min)*rng.random()

proc random*(rng: var RNG; max: float): float {.inline.} =
  ## Returns a uniformly distributed random number ``0 <= n < max``
  max*rng.random()


proc randomChoice*(rng: var RNG; arr: RAContainer): auto {.inline.} =
  ## Selects a random element (all of them have an equal chance)
  ## from a random access container and returns it
  arr[rng.randomInt(arr.low..arr.high)]


proc shuffle*(rng: var RNG; arr: var RAContainer) =
  ## Randomly shuffles elements of a random access container
  # Fisher-Yates shuffle
  for i in arr.low..arr.high:
    let j = rng.randomInt(i..arr.high)
    swap arr[j], arr[i]


iterator randomSample*(rng: var RNG; arr: RAContainer; n: Natural): auto =
  ## Simple random sample.
  ## 
  ## Yields `n` items randomly picked from a random access container `arr`,
  ## in the relative order they were in it. Each item has an equal chance to be
  ## picked and can be picked only once. Repeating items are allowed in `arr`,
  ## and they will not be treated in any special way.
  ## 
  ## Raises ``ValueError`` if there are less than `n` items in `arr`.
  if n > arr.len:
    raise newException(ValueError, "Sample can't be larger than population")
  let direct = (n <= (arr.len div 2)+10)
  # "direct" means we will be filling the set with items to include
  # "not direct" means filling it with items to exclude
  var remaining = if direct: n else: arr.len-n
  var iset: IntSet = initIntSet()
  while remaining > 0:
    let x = rng.randomInt(arr.low..arr.high)
    if not containsOrIncl(iset, x):
      dec remaining
  if direct:
    for i in iset.items():
      yield arr[i]
  else:
    for i in iset.missingItems(0, n-1):
      yield arr[i]
