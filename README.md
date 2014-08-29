```nimrod
import random

var a = @[1,2,3,4,5,6,7,8,9,10]

echo a[random_int(a.len)]
# Possible output: 9

echo a.random_choice()
# Possible output: 3

a.shuffle()
echo a
# Possible output: @[4, 8, 2, 10, 9, 3, 1, 5, 6, 7]

import algorithm
a.sort(cmp[int])

if random_bool():
    echo "heads"
else:
    echo "tails"
# Possible output: heads

var rng = init_MersenneTwister()
rng.seed(1337)
echo rng.random_int(13..37)
# Reproducible output: 31

import sequtils
echo to_seq(rng.random_sample(a, 3))
# Reproducible output: @[1, 2, 5]

rng.seed()
echo rng.random()
# Possible output: 9.9708586245117903e-01
```

[Documentation](https://rawgit.com/BlaXpirit/nimrod-random/master/doc/random.html)
