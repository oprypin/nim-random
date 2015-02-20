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


import macros, strutils

macro makeBytesSeeding*(rng, typ): stmt =
  let s = """
    proc seed*(self: $rng; bytes: openArray[uint8]) =
      ## Seeds (randomizes) using an array of bytes
      const size = sizeof($typ)
      
      # Turn an array of uint8 into an array of $typ:
      var bytes = @bytes
      let n = ((bytes.len-1) div size)+1 # n bytes is ceil(n/k) k-bit numbers
      bytes.setLen(n*size) # add the missing bytes - should be zeros
      
      var words = newSeq[$typ](n)
      for i in 0 .. <n:
        for j in 0 .. <size:
          words[i] = words[i] or ($typ(bytes[i*size+j]) shl $typ(8*j))
      self.seed(words)
  """.replace("$rng", $rng).replace("$typ", $typ)
  parseStmt s

macro makeBytesSeeding*(rng, typ, count): stmt =
  let s = """
    proc seed*(self: $rng; bytes: array[$count*sizeof($typ), uint8]) =
      ## Seeds (randomizes) using an array of bytes
      const size = sizeof($typ)
      
      # Turn an array of uint8 into an array of $typ:
      var words: array[$count, $typ]
      for i in 0 .. <$count:
        for j in 0 .. <size:
          words[i] = words[i] or ($typ(bytes[i*size+j]) shl $typ(8*j))
      self.seed(words)
  """.replace("$rng", $rng).replace("$typ", $typ).replace("$count", $count)
  parseStmt s
