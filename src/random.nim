# Copyright (c) 2014 Oleh Prypin <blaxpirit@gmail.com>
# License: MIT


import math
import unsigned
import times
import intsets

import mt19937ar

when defined(windows):
    import windows_urandom as os_urandom
when not defined(windows):
    import posix_urandom as os_urandom


proc urandom*(size: Natural): seq[uint8] {.raises: [EOS, EOutOfMemory], inline.} =
    ## Returns a ``seq`` of random integers ``0 <= n < 256`` provided by
    ## the operating system's cryptographic source (see ``posix_urandom``, ``windows_urandom``)
    os_urandom.urandom(size)



proc random_byte*[RNG](self: var RNG): uint8 =
    ## Returns a uniformly distributed random integer ``0 <= n < 256``
    assert false, "\"Abstract\"; not implemented"

proc random_int*[RNG](self: var RNG; max: Positive): Natural =
    ## Returns a uniformly distributed random integer ``0 <= n < max``
    let needed_bits = int(ceil(log2(float(max))))
    let needed_bytes = (needed_bits+7) div 8 # ceil(needed_bits/8)
    while true:
        result = 0
        for i in 1..needed_bytes:
            result = result shl 8
            result += int(self.random_byte())
        result = result shr (needed_bytes*8-needed_bits)
        if result < max:
            break

proc random*[RNG](self: var RNG): float64 =
    ## Returns a uniformly distributed random number ``0 <= n < 1``
    const MAX_PREC = 1 shl 53 # float64, excluding mantissa, has 2^53 different values
    return float64(self.random_int(MAX_PREC))/MAX_PREC

proc random_int*[RNG](self: var RNG; min, max: int): int =
    ## Returns a uniformly distributed random integer ``min <= n < max``
    min+self.random_int(max-min)

proc random_int*[RNG](self: var RNG; slice: TSlice[int]): int {.inline.} =
    ## Returns a uniformly distributed random integer ``slice.a <= n <= slice.b``
    self.random_int(slice.a, slice.b+1)

proc random_bool*[RNG](self: var RNG): bool {.inline.} =
    ## Returns a random boolean
    bool(self.random_int(2))

proc random*[RNG](self: var RNG; min, max: float): float =
    ## Returns a uniformly distributed random number ``min <= n < max``
    min+(max-min)*self.random()

proc random*[RNG](self: var RNG; max: float): float =
    ## Returns a uniformly distributed random number ``0 <= n < max``
    max*self.random()

proc random_choice*[RNG, T](self: var RNG; arr: T): auto {.inline.} =
    ## Selects a random element (all of them have an equal chance) from a 0-indexed random access container and returns it
    arr[self.random_int(arr.len)]

proc shuffle*[RNG, T](self: var RNG; arr: var openarray[T]) =
    ## Randomly shuffles elements of an array
    
    # Fisher-Yates shuffle
    for i in 0..arr.high:
        let j = self.random_int(i, arr.len)
        swap arr[j], arr[i]

iterator missing_items[T](s: var T; a, b: int): int =
    ## missing_items([2, 4], 1, 5) -> [1, 3, 5]
    var cur = a
    for el in items(s):
        while cur < el:
            yield cur
            inc cur
        inc cur
    for x in cur..b:
        yield x

iterator random_sample*[RNG, T](self: var RNG; arr: T, n: Natural): auto =
    ## Simple random sample.
    ## Yields ``n`` items randomly picked from a 0-indexed random access container ``arr``,
    ## in the relative order they were in it.
    ## Each item has an equal chance to be picked and can be picked only once.
    ## Repeating items are allowed in ``arr``, and they will not be treated in any special way.
    ## Raises ``EInvalidValue`` if there are less than ``n`` items in ``arr``.
    if n > arr.len:
        raise new_exception(EInvalidValue, "Sample can't be larger than population")
    let direct = (n <= (arr.len div 2)+10)
    # "direct" means we will be filling the set with items to include
    # "not direct" means filling it with items to exclude
    var remaining = if direct: n else: arr.len-n
    var iset: TIntSet = init_IntSet()
    while remaining > 0:
        let x = self.random_int(arr.len)
        if not contains_or_incl(iset, x):
            dec remaining
    if direct:
        for i in items(iset):
            yield arr[i]
    else:
        for i in missing_items(iset, 0, n-1):
            yield arr[i]


type TMersenneTwister* = object
    ## Mersenne Twister (MT19937).
    ## Based on http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/MT2002/emt19937ar.html
    state: TMTState
    bytes_it: iterator (self: var TMersenneTwister): uint8 {.closure.}

iterator mt_random_bytes(self: var TMersenneTwister): uint8 {.closure.} =
    while true:
        let n: uint32 = self.state.genrand_int32()
        yield uint8(n)
        yield uint8(n shr 8)
        yield uint8(n shr 16)
        yield uint8(n shr 24)

proc random_byte*(self: var TMersenneTwister): uint8 =
    self.bytes_it(self)

proc random*(self: var TMersenneTwister): float64 =
    self.state.genrand_res53()

proc init_MersenneTwister*(): TMersenneTwister =
    ## Initializes and returns a new ``TMersenneTwister``
    result.state = init_MTState()
    result.bytes_it = mt_random_bytes

proc seed*(self: var TMersenneTwister; seed: int) =
    ## Seeds (randomizes) using 32 bits of an integer
    self.state.init_genrand(cast[uint32](seed))

proc seed*(self: var TMersenneTwister; seed: openarray[uint8]) =
    ## Seeds (randomizes) using an array of bytes
    
    # Turn an array of uint8 into an array of uint32:
    
    var bytes = @seed
    let n = int(ceil(bytes.len/4)) # n bytes is ceil(n/4) 32bit numbers
    bytes.set_len(n*4) # add the missing bytes - should be zeros
    
    var words = new_seq[uint32](n)
    for i in 0..n-1:
        let i4 = i*4
        words[i] = bytes[i4] or bytes[i4+1] shl 8 or bytes[i4+2] shl 16 or bytes[i4+3] shl 24
    
    self.state.init_by_array(words)

proc seed*(self: var TMersenneTwister) =
    ## Seeds (randomizes) using an array of bytes provided by ``urandom``, or,
    ## in case of failure, using the current time (with resolution of 1/256 sec)
    try:
        self.seed(urandom(2500))
    except EOS:
        self.seed(int(epoch_time()*256))



type TSystemRandom* = object
    ## Random number generator based on bytes provided by
    ## the operating system's cryptographic source (see ``urandom``)
    bytes_it: iterator (self: var TSystemRandom): uint8 {.closure.}

iterator sys_random_bytes(self: var TSystemRandom): uint8 {.closure.} =
    # Get bytes in chunks so we don't need to ask the OS for them
    # multiple times per generated random number...
    while true:
        for b in urandom(128):
            yield b

proc random_byte*(self: var TSystemRandom): uint8 =
    self.bytes_it(self)

proc init_SystemRandom*(): TSystemRandom =
    ## Initializes and returns a new ``TSystemRandom``
    result.bytes_it = sys_random_bytes




var mersenne_twister_inst* = init_MersenneTwister()
    ## A global instance of MT used by the alias functions.
    ## ``seed()`` is called on it when the module is imported
mersenne_twister_inst.seed()

proc random_byte*(): uint8 {.inline.} =
    ## Alias to MT
    mersenne_twister_inst.random_byte()
proc random*(): float64 {.inline.} =
    ## Alias to MT
    mersenne_twister_inst.random()
proc random*(max: float): float {.inline.} =
    ## Alias to MT
    mersenne_twister_inst.random(max)
proc random*(min, max: float): float {.inline.} =
    ## Alias to MT
    mersenne_twister_inst.random(min, max)
proc random_int*(max: Positive): Natural {.inline.} =
    ## Alias to MT
    mersenne_twister_inst.random_int(max)
proc random_int*(min, max: int): int {.inline.} =
    ## Alias to MT
    mersenne_twister_inst.random_int(min, max)
proc random_int*(slice: TSlice[int]): int {.inline.} =
    ## Alias to MT
    mersenne_twister_inst.random_int(slice)
proc random_bool*(): bool {.inline.} =
    ## Alias to MT
    mersenne_twister_inst.random_bool()
proc random_choice*[T](arr: T): auto {.inline.} =
    ## Alias to MT
    mersenne_twister_inst.random_choice(arr)
proc shuffle*[T](arr: var openarray[T]) {.inline.} =
    ## Alias to MT
    mersenne_twister_inst.shuffle(arr)
iterator random_sample*[T](arr: T, n: Natural): auto {.inline.} =
    ## Alias to MT
    for x in mersenne_twister_inst.random_sample(arr, n):
        yield x
