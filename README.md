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

var rng = initMersenneTwister(1337)
echo rng.randomInt(13..37)
# Reproducible output: 36

echo toSeq(rng.randomSample(a, 3))
# Reproducible output: @[8, 9, 10]

rng = initMersenneTwister(urandom(2500))
echo rng.random()
# Possible output: 0.6097267717528587
```

[Documentation](http://blaxpirit.github.io/nim-random/random.html)
