[![Build Status](https://circleci.com/gh/BlaXpirit/nim-random.png?style=shield)](https://circleci.com/gh/BlaXpirit/nim-random)

[Documentation](http://blaxpirit.github.io/nim-random/)

```nim
import algorithm, sequtils
import random, random.xorshift

var a = toSeq(1..10)

echo a[randomInt(a.len)]
# Possible output: 9

echo a.randomChoice()
# Possible output: 3

a.shuffle()
echo a
# Possible output: @[4, 8, 2, 10, 9, 3, 1, 5, 6, 7]

a.sort(cmp[int])

if randomBool():
  echo "heads"
else:
  echo "tails"
# Possible output: heads

var rng = initXorshift128Plus(1337)
echo rng.randomInt(13..37)
# Reproducible output: 27

echo toSeq(rng.randomSample(a, 3))
# Reproducible output: @[5, 9, 10]

var rng2 = initMersenneTwister(urandom(2500))
echo rng2.random()
# Possible output: 0.6097267717528587```

[Credits](CREDITS.md)
