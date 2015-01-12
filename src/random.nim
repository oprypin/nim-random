# Copyright (c) 2014 Oleh Prypin <blaxpirit@gmail.com>
# License: MIT


import math
import unsigned
import times
import intsets

import mt19937ar

when defined(windows):
  import windows_urandom as os_urandom
else:
  import posix_urandom as os_urandom


proc urandom*(size: Natural): seq[uint8] {.raises: [OSError], inline.} =
  ## Returns a ``seq`` of random integers ``0 <= n < 256`` provided by
  ## the operating system's cryptographic source (see ``posix_urandom``, ``windows_urandom``)
  os_urandom.urandom(size)



proc randomByte*[RNG](self: var RNG): uint8 =
  ## Returns a uniformly distributed random integer ``0 <= n < 256``
  assert false, "\"Abstract\"; not implemented"

proc randomInt*[RNG](self: var RNG; max: Positive): Natural =
  ## Returns a uniformly distributed random integer ``0 <= n < max``
  let neededBits = int(ceil(log2(float(max))))
  let neededBytes = (neededBits+7) div 8 # ceil(neededBits/8)
  while true:
    result = 0
    for i in 1..neededBytes:
      result = result shl 8
      result += int(self.randomByte())
    result = result shr (neededBytes*8-neededBits)
    if result < max:
      break

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

proc random*[RNG](self: var RNG; max: float): float =
  ## Returns a uniformly distributed random number ``0 <= n < max``
  max*self.random()

proc randomChoice*[RNG, T](self: var RNG; arr: T): auto {.inline.} =
  ## Selects a random element (all of them have an equal chance) from a 0-indexed random access container and returns it
  arr[self.randomInt(arr.len)]

proc shuffle*[RNG, T](self: var RNG; arr: var openarray[T]) =
  ## Randomly shuffles elements of an array
  
  # Fisher-Yates shuffle
  for i in 0..arr.high:
    let j = self.randomInt(i, arr.len)
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
  ## Yields ``n`` items randomly picked from a 0-indexed random access container ``arr``,
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
    let x = self.randomInt(arr.len)
    if not containsOrIncl(iset, x):
      dec remaining
  if direct:
    for i in items(iset):
      yield arr[i]
  else:
    for i in missingItems(iset, 0, n-1):
      yield arr[i]


type TMersenneTwister* = object
  ## Mersenne Twister (MT19937).
  ## Based on http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/MT2002/emt19937ar.html
  state: TMTState
  bytesIt: iterator (self: var TMersenneTwister): uint8 {.closure.}

iterator mtRandomBytes(self: var TMersenneTwister): uint8 {.closure.} =
  while true:
    let n: uint32 = self.state.genrandInt32()
    yield uint8(n)
    yield uint8(n shr 8'u32)
    yield uint8(n shr 16'u32)
    yield uint8(n shr 24'u32)

proc randomByte*(self: var TMersenneTwister): uint8 =
  self.bytesIt(self)

proc random*(self: var TMersenneTwister): float64 =
  self.state.genrandRes53()

proc initMersenneTwister*(): TMersenneTwister =
  ## Initializes and returns a new ``TMersenneTwister``
  result.state = initMTState()
  result.bytesIt = mtRandomBytes

proc seed*(self: var TMersenneTwister; seed: int) =
  ## Seeds (randomizes) using 32 bits of an integer
  self.state.initGenrand(cast[uint32](seed))

proc seed*(self: var TMersenneTwister; seed: openarray[uint8]) =
  ## Seeds (randomizes) using an array of bytes
  
  # Turn an array of uint8 into an array of uint32:
  
  var bytes = @seed
  let n = int(ceil(bytes.len/4)) # n bytes is ceil(n/4) 32bit numbers
  bytes.setLen(n*4) # add the missing bytes - should be zeros
  
  var words = newSeq[uint32](n)
  for i in 0..n-1:
    let i4 = i*4
    words[i] = uint32(bytes[i4]) or uint32(bytes[i4+1]) shl 8'u32 or
      uint32(bytes[i4+2]) shl 16'u32 or uint32(bytes[i4+3]) shl 24'u32
  
  self.state.initByArray(words)

proc seed*(self: var TMersenneTwister) =
  ## Seeds (randomizes) using an array of bytes provided by ``urandom``, or,
  ## in case of failure, using the current time (with resolution of 1/256 sec)
  try:
    self.seed(urandom(2500))
  except OSError:
    self.seed(int(epochTime()*256))



type TSystemRandom* = object
  ## Random number generator based on bytes provided by
  ## the operating system's cryptographic source (see ``urandom``)
  bytesIt: iterator (self: var TSystemRandom): uint8 {.closure.}

iterator sysRandomBytes(self: var TSystemRandom): uint8 {.closure.} =
  # Get bytes in chunks so we don't need to ask the OS for them
  # multiple times per generated random number...
  while true:
    for b in urandom(128):
      yield b

proc randomByte*(self: var TSystemRandom): uint8 =
  self.bytesIt(self)

proc initSystemRandom*(): TSystemRandom =
  ## Initializes and returns a new ``TSystemRandom``
  result.bytesIt = sysRandomBytes




var mersenneTwisterInst* = initMersenneTwister()
  ## A global instance of MT used by the alias functions.
  ## ``seed()`` is called on it when the module is imported
mersenneTwisterInst.seed()

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
proc shuffle*[T](arr: var openarray[T]) {.inline.} =
  ## Alias to MT
  mersenneTwisterInst.shuffle(arr)
iterator randomSample*[T](arr: T, n: Natural): auto {.inline.} =
  ## Alias to MT
  for x in mersenneTwisterInst.randomSample(arr, n):
    yield x
