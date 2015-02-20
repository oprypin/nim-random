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
import common, private/seeding
import private/xorshift128plus, private/xorshift1024star, private/xorshift64star
from private/murmurhash3 import nil
export common


type Xorshift128Plus* = Xorshift128PlusState
  ## xorshift128+
  ## based on http://xorshift.di.unimi.it/

proc initXorshift128Plus*(): Xorshift128Plus =
  ## Initializes and returns a new ``Xorshift128Plus``

proc randomUint64*(self: var Xorshift128Plus): uint64 {.inline.} =
  xorshift128plus.next(self)

proc checkSeed(self: var Xorshift128Plus) {.inline.} =
  if (self.s[0] or self.s[1]) == 0:
    raise newException(ValueError,
      "The state must be seeded so that it is not everywhere zero.")

proc seed*(self: var Xorshift128Plus, seed: array[2, uint64]) {.inline.} =
  ## Seeds (randomizes) using 2 ``uint64``.
  ## The state must be seeded so that it is not everywhere zero.
  self.s = seed
  self.checkSeed()

makeBytesSeeding("var Xorshift128Plus", "uint64", "2")

proc seed*(self: var Xorshift128Plus, seed: uint64) {.inline.} =
  ## Seeds (randomizes) using an ``uint64``.
  ## The state must be seeded so that it is not everywhere zero.
  # "If you have a 64-bit seed, we suggest to pass it twice
  # through MurmurHash3's avalanching function."
  let a = murmurhash3.next(seed)
  let b = murmurhash3.next(a)
  self.s = [a, b]
  self.checkSeed()


type Xorshift1024Star* = Xorshift1024StarState
  ## xorshift1024*
  ## based on http://xorshift.di.unimi.it/

proc initXorshift1024Star*(): Xorshift1024Star =
  ## Initializes and returns a new ``Xorshift1024Star``

proc randomUint64*(self: var Xorshift1024Star): uint64 {.inline.} =
  xorshift1024star.next(self)

proc checkSeed(self: var Xorshift1024Star) {.inline.} =
  var r: uint64
  for x in self.s:
    r = r or x
  if r == 0:
    raise newException(ValueError,
      "The state must be seeded so that it is not everywhere zero.")

proc seed*(self: var Xorshift1024Star, seed: array[16, uint64]) {.inline.} =
  ## Seeds (randomizes) using 16 uint64.
  ## The state must be seeded so that it is not everywhere zero.
  self.s = seed
  self.p = 0
  self.checkSeed()

makeBytesSeeding("var Xorshift1024Star", "uint64", "16")

proc seed*(self: var Xorshift1024Star, seed: uint64) {.inline.} =
  ## Seeds (randomizes) using an uint64.
  ## The state must be seeded so that it is not everywhere zero.
  # "If you have a 64-bit seed, we suggest to seed a
  # xorshift64* generator and use its output to fill s."
  var r: array[16, uint64]
  var rng = Xorshift64StarState(x: seed)
  for x in r.mitems:
    x = xorshift64star.next(rng)
  self.seed(r)
