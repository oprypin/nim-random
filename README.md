This is an alternative version of this library that disables `randomSample` but works with Nim 0.10.2.

    nimble install random@#old-compiler

```nim
import algorithm, sequtils
import random

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

var rng = initMersenneTwister()
rng.seed(1337)
echo rng.randomInt(13..37)
# Reproducible output: 31

# echo toSeq(rng.randomSample(a, 3))  # DISABLED IN THIS VERSION
# Reproducible output: @[1, 2, 5]

rng.seed()
echo rng.random()
# Possible output: 9.9708586245117903e-01
```

[Documentation](http://htmlpreview.github.io/?https://github.com/BlaXpirit/nim-random/blob/f7d814cc52c6ac4b3059757d72fab4d204400088/random.html)
