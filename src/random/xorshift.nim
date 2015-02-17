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


import unsigned, math, times
import common, private/xorshift128plus
export common


type Xorshift128Plus* = Xorshift128PlusState
  ## xorshift128+
  ## based on http://xorshift.di.unimi.it/

proc initXorshift128Plus*(): Xorshift128Plus =
  ## Initializes and returns a new ``Xorshift128Plus``

proc randomUint64*(self: var Xorshift128Plus): uint64 {.inline.} =
  self.next()

proc seed*(self: var Xorshift128Plus, arr: array[2, uint64]) {.inline.} =
  self[0] = arr[0]
  self[1] = arr[1]