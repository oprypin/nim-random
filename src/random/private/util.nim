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


import unsigned, intsets


iterator missingItems*[T](s: T; a, b: int): int =
  ## Yields numbers ``in a..b`` that are missing from the ordered sequence `s`
  var cur = a
  for el in items(s):
    while cur < el:
      yield cur
      inc cur
    inc cur
  for x in cur..b:
    yield x


proc byteSizeFallback(n: uint): int =
  ## Returns the smallest number `b` that `256^b <= n`
  var n = n
  while true:
    inc result
    n = n shr 8
    if n == 0:
      break

when defined(gcc):
  proc gcc_clz(n: culong): cint {.importc: "__builtin_clzl".}
  
  proc bitSize(n: uint): int {.inline.} =
    sizeof(uint)*8 - gcc_clz(n)
  
  proc byteSize*(n: uint): int {.inline.} =
    (bitSize(n)+7) div 8

else:
  proc byteSize*(n: uint): int {.inline.} =
    byteSizeFallback(n)


when defined(test):
  import unittest, sequtils

  suite "Utilities":
    echo "Utilities:"
    
    test "missingItems":
      for data in [
        (@[1, 3, 5], 1, 5, @[2, 4]),
        (@[2, 3, 4], 1, 5, @[1, 5]),
        (@[], 1, 5, @[1, 2, 3, 4, 5]),
        (@[1, 2, 3, 4, 5], 1, 5, @[]),
      ]:
        # check is bugged
        let (s, a, b, output) = data
        assert toSeq(missingItems(s, a, b)) == output
    
    test "byteSize":
      for data in [
        (0u, 1), (1u, 1), (2u, 1), (16u, 1), (255u, 1), (256u, 2),
        (1u shl 24 - 1u, 3), (1u shl 24, 4)
      ]:
        let (input, output) = data
        check byteSize(input) == output
        check byteSizeFallback(input) == output
