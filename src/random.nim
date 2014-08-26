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



type TRandomGenerator* = object of TObject
    ## Base class for random number generators

method random_byte*(self: var TRandomGenerator): uint8 =
    ## Returns a uniformly distributed random integer ``0 <= n < 256``
    assert false, "Abstract method; not implemented"

proc random_int*(self: var TRandomGenerator; max: Positive): Natural =
    ## Returns a uniformly distributed random integer ``0 <= n < max``
    while true:
        result = 0
        let needed_bits = int(ceil(log2(float(max))))
        let needed_bytes = int(ceil(needed_bits/8))
        for i in 1..needed_bytes:
            result = result shl 8
            result += int(self.random_byte())
        result = result shr (needed_bytes*8-needed_bits)
        if result < max:
            break

method random*(self: var TRandomGenerator): float64 =
    ## Returns a uniformly distributed random number ``0 <= n < 1``
    const MAX_PREC = 1 shl 53 # float64, excluding mantissa, has 2^53 different values
    return float64(self.random_int(MAX_PREC))/MAX_PREC

proc random_int*(self: var TRandomGenerator; min, max: int): int =
    ## Returns a uniformly distributed random integer ``min <= n < max``
    min+self.random_int(max-min)

proc random_int*(self: var TRandomGenerator; slice: TSlice[int]): int {.inline.} =
    ## Returns a uniformly distributed random integer ``slice.a <= n <= slice.b``
    self.random_int(slice.a, slice.b+1)

proc random_bool*(self: var TRandomGenerator): bool {.inline.} =
    ## Returns a random boolean
    bool(self.random_int(2))

proc random*(self: var TRandomGenerator; min, max: float): float =
    ## Returns a uniformly distributed random number ``min <= n < max``
    min+(max-min)*self.random()

proc random*(self: var TRandomGenerator; max: float): float =
    ## Returns a uniformly distributed random number ``0 <= n < max``
    max*self.random()

proc random_choice*[T](self: var TRandomGenerator; arr: openarray[T]): T {.inline.} =
    ## Selects a random element from an array (all of them have an equal chance) and returns it
    arr[self.random_int(arr.len)]

proc shuffle*[T](self: var TRandomGenerator; arr: var openarray[T]) =
    ## Randomly shuffles elements of an array
    
    # Fisher-Yates shuffle
    for i in 0..arr.high:
        let j = self.random_int(i, arr.len)
        swap arr[j], arr[i]

iterator missing_items[T](s: var T; a, b: int): int =
    ## missing_items([2, 4], 1, 5) -> [1, 3, 5]
    var cur = a
    for el in items(s):
        while cur<el:
            yield cur
            inc cur
        inc cur
    for x in cur..b:
        yield x

iterator random_sample*[T](self: var TRandomGenerator; arr: openarray[T], n: Natural): T =
    ## Simple random sample.
    ## Yields ``n`` items randomly picked from ``arr``, in the relative order they were in it.
    ## Each item has an equal chance to be picked and can be picked only once.
    ## Repeating items are allowed in ``arr``, and they will not be treated in any special way.
    ## Raises ``EInvalidValue`` if there are less than ``n`` items in ``arr``.
    if n>arr.len:
        raise new_exception(EInvalidValue, "Sample can't be larger than population")
    let direct = arr.len <= (n div 2)+10
    # "direct" means we will be filling the set with items to include
    # "not direct" means filling it with items to exclude
    var remaining = if direct: n else: arr.len-n
    var iset: TIntSet = init_IntSet()
    while remaining>0:
        let x = self.random_int(arr.len)
        if not contains_or_incl(iset, x):
            dec(remaining)
    if direct:
        for i in items(iset):
            yield arr[i]
    else:
        for i in missing_items(iset, 0, n-1):
            yield arr[i]


type TMersenneTwister* = object of TRandomGenerator
    ## Mersenne Twister (MT19937).
    ## Based on http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/MT2002/emt19937ar.html
    state: TMTState

proc init_MersenneTwister*(): TMersenneTwister =
    ## Initializes and returns a new ``TMersenneTwister``
    result.state = init_MTState()

proc seed*(self: var TMersenneTwister; seed: int) =
    ## Seeds (randomizes) using 32 bits of an integer
    self.state.init_genrand(cast[uint32](seed))

proc seed*(self: var TMersenneTwister; seed: openarray[uint8]) =
    ## Seeds (randomizes) using an array of bytes
    
    # Cast array of uint8 to array of uint32:
    
    var bytes = @seed
    let n = int(ceil(bytes.len/4)) # n bytes is ceil(n/4) 32bit numbers
    bytes.set_len(n*4) # add the missing bytes - should be zeros
    
    # forceful cast makes it think that it takes 4 times more memory than it really does
    let words_bad = cast[seq[uint32]](bytes)
    # don't use this seq directly
    
    var words = new_seq[uint32](n)
    words.set_len(n)
    for i in 0..n-1:
        words[i] = words_bad[i]
    
    self.state.init_by_array(words)

proc seed*(self: var TMersenneTwister) =
    ## Seeds (randomizes) using an array of bytes provided by ``urandom``, or,
    ## in case of failure, using the current time (with resolution of 1/256 sec)
    try:
        self.seed(urandom(2500))
    except EOS:
        self.seed(int(epoch_time()*256)) # use fractional seconds

iterator mt_random_bytes(self: var TMersenneTwister): uint8 {.closure.} =
    while true:
        let n: uint32 = self.state.genrand_int32()
        yield uint8(n)
        yield uint8(n shr 8)
        yield uint8(n shr 16)
        yield uint8(n shr 24)

method random_byte*(self: var TMersenneTwister): uint8 =
    let it = mt_random_bytes
    return it(self)

method random*(self: var TMersenneTwister): float64 =
    self.state.genrand_res53()


type TSystemRandom* = object of TRandomGenerator
    ## Random number generator based on bytes provided by
    ## the operating system's cryptographic source (see ``urandom``)

proc init_SystemRandom*(): TSystemRandom =
    ## Returns a new ``TSystemRandom``

iterator sys_random_bytes(self: var TSystemRandom): uint8 {.closure.} =
    # Get bytes in chunks so we don't need to ask the OS for them
    # multiple times per generated random number...
    while true:
        for b in urandom(128):
            yield b

method random_byte*(self: var TSystemRandom): uint8 =
    let it = sys_random_bytes
    return it(self)



var mersenne_twister_inst* = init_MersenneTwister()
    ## A global instance of MT used by the alias functions
mersenne_twister_inst.seed()
# Why won't this work if ``mersenne_twister_inst`` is not public?

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
proc random_choice*[T](arr: openarray[T]): T {.inline.} =
    ## Alias to MT
    mersenne_twister_inst.random_choice(arr)
proc shuffle*[T](arr: var openarray[T]) {.inline.} =
    ## Alias to MT
    mersenne_twister_inst.shuffle(arr)
iterator random_sample*[T](arr: openarray[T], n: Natural): T {.inline.} =
    ## Alias to MT
    for x in mersenne_twister_inst.random_sample(arr, n):
        yield x
