# Code in this module is based on:
# http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/MT2002/emt19937ar.html
# 
# It was ported to Nim in 2014 by Oleh Prypin <blaxpirit@gmail.com>
# 
# The following are the verbatim comments from the original code:

discard """

A C-program for MT19937, with initialization improved 2002/1/26.
Coded by Takuji Nishimura and Makoto Matsumoto.

Before using, initialize the state by using init_genrand(seed)
or init_by_array(init_key, key_length).

Copyright (C) 1997-2002, Makoto Matsumoto and Takuji Nishimura,
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.

  2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.

  3. The names of its contributors may not be used to endorse or promote
     products derived from this software without specific prior written
     permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


Any feedback is very welcome.
http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html
email: m-mat @ math.sci.hiroshima-u.ac.jp (remove space)

"""


import unsigned


# Period parameters
const
    N = 624
    M = 397
    MATRIX_A = 0x9908B0DF'u32
    UPPER_MASK = 0x80000000'u32
    LOWER_MASK = 0x7FFFFFFF'u32

type
    MTState* = object
        ## state of Mersenne Twister
        mt: array[N, uint32]
        mti: int
    

proc init_MTState*(): MTState =
    ## initializes and returns a new ``MTState``
    result.mti = N+1

proc init_genrand*(self: var MTState; s: uint32) =
    ## initializes ``mt[N]`` with a seed

    # ``mti == N+1`` means ``mt[N]`` is not initialized
    self.mt[0] = s #and 0xFFFFFFFF'u32 # not needed because it's ``uint32``
    self.mti = 1
    while self.mti < N:
        self.mt[self.mti] =
            1812433253'u32 * (self.mt[self.mti-1] xor (self.mt[self.mti-1] shr 30)) + uint32(self.mti)
        # See Knuth TAOCP Vol2. 3rd Ed. P.106 for multiplier.
        # In the previous versions, MSBs of the seed affect
        # only MSBs of the array mt[].
        # 2002/01/09 modified by Makoto Matsumoto
        
        #self.mt[self.mti] = self.mt[self.mti] and 0xFFFFFFFF'u32
        # for > 32 bit machines # not needed because it's ``uint32``
        
        inc(self.mti)

proc init_by_array*(self: var MTState; init_key: openArray[uint32]) =
    ## initialize by an array with array-length.
    ## `init_key` is the array for initializing keys.
    
    # slight change for C++, 2004/2/26
    
    let key_length = init_key.len
    self.init_genrand(19650218'u32)
    var
        i = 1
        j = init_key.low
    for k in countdown(if N > key_length: N else: key_length, 1):
        self.mt[i] =
            self.mt[i] xor ((self.mt[i-1] xor (self.mt[i-1] shr 30)) * 1664525'u32) +
            init_key[j] + uint32(j) # non linear
        #self.mt[i] = self.mt[i] and 0xFFFFFFFF'u32 # for WORDSIZE > 32 machines # not needed because it's ``uint32``
        inc(i)
        inc(j)
        if i >= N:
            self.mt[0] = self.mt[N-1]
            i = 1
        if j > init_key.high:
            j = init_key.low
    for k in countdown(N-1, 1):
        self.mt[i] =
            self.mt[i] xor ((self.mt[i-1] xor (self.mt[i-1] shr 30)) * 1566083941'u32) -
            uint32(i) # non linear
        #self.mt[i] = self.mt[i] and 0xFFFFFFFF'u32 # for WORDSIZE > 32 machines # not needed because it's ``uint32``
        inc(i)
        if i >= N:
            self.mt[0] = self.mt[N-1]
            i = 1
    self.mt[0] = 0x80000000'u32  # MSB is 1; assuring non-zero initial array

proc genrand_int32*(self: var MTState): uint32 =
    ## generates a random number on [0,0xffffffff]-interval
    var y: uint32
    let mag01 = [0'u32, MATRIX_A]
    # mag01[x] = x*MATRIX_A  for x=0,1
    
    if self.mti >= N:
        # generate N words at one time

        if self.mti == N+1:
            self.init_genrand(5489'u32)

        var kk = 0
        while kk < N-M:
            y = (self.mt[kk] and UPPER_MASK) or (self.mt[kk+1] and LOWER_MASK)
            self.mt[kk] = self.mt[kk+M] xor (y shr 1) xor mag01[int(y and 0x1'u32)]
            inc(kk)
        while kk < N-1:
            y = (self.mt[kk] and UPPER_MASK) or (self.mt[kk+1] and LOWER_MASK)
            self.mt[kk] = self.mt[kk+(M-N)] xor (y shr 1) xor mag01[int(y and 0x1'u32)]
            inc(kk)
        y = (self.mt[N-1] and UPPER_MASK) or (self.mt[0] and LOWER_MASK)
        self.mt[N-1] = self.mt[M-1] xor (y shr 1) xor mag01[int(y and 0x1'u32)]

        self.mti = 0

    y = self.mt[self.mti]
    inc(self.mti)
    
    # Tempering
    y = y xor (y shr 11)
    y = y xor (y shl 7) and 0x9D2C5680'u32
    y = y xor (y shl 15) and 0xEFC60000'u32
    y = y xor (y shr 18)
    
    return y

proc genrand_int31*(self: var MTState): int32 =
    ## generates a random number on [0,0x7fffffff]-interval
    return int32(self.genrand_int32() shr 1)

proc genrand_real1*(self: var MTState): float64 =
    ## generates a random number on [0,1]-real-interval
    return float64(self.genrand_int32())*(1.0/4294967295.0)
    # divided by 2^32-1

proc genrand_real2*(self: var MTState): float64 =
    ## generates a random number on [0,1)-real-interval
    return float64(self.genrand_int32())*(1.0/4294967296.0)
    # divided by 2^32

proc genrand_real3*(self: var MTState): float64 =
    ## generates a random number on (0,1)-real-interval
    return (float64(self.genrand_int32())+0.5)*(1.0/4294967296.0)
    # divided by 2^32

proc genrand_res53*(self: var MTState): float64 =
    ## generates a random number on [0,1) with 53-bit resolution
    let
        a = self.genrand_int32() shr 5
        b = self.genrand_int32() shr 6
    return (float64(a)*67108864.0+float64(b))*(1.0/9007199254740992.0)
# These real versions are due to Isaku Wada, 2002/01/09 added


when is_main_module:
    proc printf(fmt: cstring) {.importc: "printf", varargs, header: "<stdio.h>".}

    var state = init_MTState()
    
    state.init_by_array(@[0x00000123'u32, 0x00000234'u32, 0x00000345'u32, 0x00000456'u32])
    printf("1000 outputs of genrand_int32()\n")
    for i in 0..999:
        printf("%10lu ", state.genrand_int32())
        if i mod 5 == 4: printf("\n")
    printf("\n1000 outputs of genrand_real2()\n")
    for i in 0..999:
        printf("%10.8f ", state.genrand_real2())
        if i mod 5 == 4: printf("\n")


{.deprecated: [TMTState: MTState].}
