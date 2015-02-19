# Code in this module is based on:
# http://xorshift.di.unimi.it/xorshift64star.c
# 
# It was ported to Nim in 2015 by Oleh Prypin <blaxpirit@gmail.com>
# 
# The following are the verbatim comments from the original code:

discard """

Written in 2014 by Sebastiano Vigna (vigna@acm.org)

To the extent possible under law, the author has dedicated all copyright
and related and neighboring rights to this software to the public domain
worldwide. This software is distributed without any warranty.

See <http://creativecommons.org/publicdomain/zero/1.0/>.


This is a good generator if you're short on memory, but otherwise we
rather suggest to use a xorshift128+ (for maximum speed) or
xorshift1024* (for speed and very long period) generator.

"""


import unsigned


type Xorshift64StarState* = uint64
# The state must be seeded with a nonzero value.

proc next*(x: var Xorshift64StarState): uint64 =
  x = x xor (x shr 12) # a
  x = x xor (x shl 25) # b
  x = x xor (x shr 27) # c
  return x * 2685821657736338717'u64
