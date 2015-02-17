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


import math, intsets, unsigned


proc randomUint64[RNG](self: var RNG): uint64 =
  self.randomUint32() or (self.randomUint32() shl 32)

proc randomInt*[RNG](self: var RNG; max: Positive): Natural =
  ## Returns a uniformly distributed random integer ``0 <= n < max``
  var mask = uint(max)
  # The mask will be the closest power of 2 minus one
  # It has the same number of bits as `max`, but consists only of 1-bits
  for i in 0..5: # 1, 2, 4, 8, 16, 32
    mask = mask or (mask shr uint(1 shl i))
  when compiles(self.randomUint64()):
    if sizeof(int) == 4 or uint32(max) <= uint32.high:
      while true:
        result = uint(
          when compiles(self.randomUint32()):
            self.randomUint32()
          else:
            self.randomUint64()
        ) and mask
        if result < max: break
    else:
      while true:
        result = uint(self.randomUint64()) and mask
        if result < max: break
  else:
    var neededBytes = 0
    var remaining: int = max
    while remaining > 0:
      neededBytes += 1
      remaining = remaining shr 8
    while true:
      var res: uint = 0
      for i in 1..neededBytes:
        res = res shl 8 or self.randomByte()
      result = res and mask
      if result < max: break

proc randomByte*[RNG](self: var RNG): uint8 =
  ## Returns a uniformly distributed random integer ``0 <= n < 256``
  uint8(self.randomInt(256))

proc random*[RNG](self: var RNG): float64 =
  ## Returns a uniformly distributed random number ``0 <= n < 1``
  const MAX_PREC = 1 shl 53 # float64, excluding mantissa, has 2^53 different values
  return float64(self.randomInt(MAX_PREC))/MAX_PREC

proc randomInt*[RNG](self: var RNG; min, max: int): int =
  ## Returns a uniformly distributed random integer ``min <= n < max``
  min+self.randomInt(max-min)

proc randomInt*[RNG](self: var RNG; slice: Slice[int]): int {.inline.} =
  ## Returns a uniformly distributed random integer ``slice.a <= n <= slice.b``
  self.randomInt(slice.a, slice.b+1)

proc randomBool*[RNG](self: var RNG): bool {.inline.} =
  ## Returns a random boolean
  bool(self.randomInt(2))

proc random*[RNG](self: var RNG; min, max: float): float =
  ## Returns a uniformly distributed random number ``min <= n < max``
  min+(max-min)*self.random()

proc random*[RNG](self: var RNG; max: float): float {.inline.} =
  ## Returns a uniformly distributed random number ``0 <= n < max``
  max*self.random()

proc randomChoice*[RNG, T](self: var RNG; arr: T): auto {.inline.} =
  ## Selects a random element (all of them have an equal chance)
  ## from a random access container and returns it
  arr[self.randomInt(arr.low..arr.high)]

proc shuffle*[RNG, T](self: var RNG; arr: var T) =
  ## Randomly shuffles elements of a random access container
  
  # Fisher-Yates shuffle
  for i in arr.low..arr.high:
    let j = self.randomInt(i..arr.high)
    swap arr[j], arr[i]

iterator missingItems[T](s: var T; a, b: int): int =
  ## missingItems([2, 4], 1, 5) -> [1, 3, 5]
  var cur = a
  for el in items(s):
    while cur < el:
      yield cur
      inc cur
    inc cur
  for x in cur..b:
    yield x

iterator randomSample*[RNG, T](self: var RNG; arr: T, n: Natural): auto =
  ## Simple random sample.
  ## Yields ``n`` items randomly picked from a random access container ``arr``,
  ## in the relative order they were in it.
  ## Each item has an equal chance to be picked and can be picked only once.
  ## Repeating items are allowed in ``arr``, and they will not be treated in any special way.
  ## Raises ``ValueError`` if there are less than ``n`` items in ``arr``.
  if n > arr.len:
    raise newException(ValueError, "Sample can't be larger than population")
  let direct = (n <= (arr.len div 2)+10)
  # "direct" means we will be filling the set with items to include
  # "not direct" means filling it with items to exclude
  var remaining = if direct: n else: arr.len-n
  var iset: IntSet = initIntSet()
  while remaining > 0:
    let x = self.randomInt(arr.low..arr.high)
    if not containsOrIncl(iset, x):
      dec remaining
  if direct:
    for i in iset.items():
      yield arr[i]
  else:
    for i in iset.missingItems(0, n-1):
      yield arr[i]
