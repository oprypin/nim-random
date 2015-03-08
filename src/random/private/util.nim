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


proc divCeil*(a, b: SomeInteger): SomeInteger {.inline.} =
  ## Returns ``ceil(a / b)`` (only works on positive numbers)
  (a-1+b) div b


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


type RAContainer*[T] = generic c
  ## Random access container
  c.low is SomeInteger
  c.high is SomeInteger
  c.len is SomeInteger
  # c[i] is T ???


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
    divCeil(bitSize(n), 8)

else:
  proc byteSize*(n: uint): int {.inline.} =
    byteSizeFallback(n)


proc bytesToWords*[T](bytes: openArray[uint8]): seq[T] =
  const size = sizeof(T)
  # Turn an array of uint8 into an array of T:
  let n = (bytes.high div size)+1 # n bytes is ceil(n/k) k-bit numbers
  result = newSeq[T](n)
  for i in 0 .. <n:
    for j in 0 .. <size:
      let index = i*size+j
      let data: T =
        if index < bytes.len: bytes[index]
        else: 0
      result[i] = result[i] or (data shl T(8*j))

proc bytesToWordsN*[T, R](bytes: openArray[uint8]): R =
  const size = sizeof(T)
  # Turn an array of uint8 into an array of T:
  for i in 0 .. result.high:
    for j in 0 .. <size:
      let data: T = bytes[i*size+j]
      result[i] = result[i] or (data shl T(8*j))


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
    
    test "bytesToWords":
      for data in [
        (@[0u8, 0, 0, 0, 0, 0, 0, 0], @[0u64]),
        (@[7u8, 0, 0, 0, 0, 0, 0, 0], @[7u64]),
        (@[0u8, 0, 0, 0, 0, 0, 0, 255, 3], @[255u64 shl 56, 3]),
      ]:
        let (input, output) = data
        let result = bytesToWords[uint64](input)
        check result == output
    
    test "bytesToWordsN":
      for data in [
        ([0u8, 0, 0, 0, 0, 0, 0, 0], [0u32, 0u32]),
        ([5u8, 0, 0, 8, 0, 2, 6, 0],
           [5u32+(8u32 shl 24), (2u32 shl 8)+(6u32 shl 16)]),
      ]:
        let (input, output) = data
        let result = bytesToWordsN[uint32, array[2, uint32]](input)
        check result == output
