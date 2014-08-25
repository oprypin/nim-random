```nimrod
import random

var a = @[1,2,3,4,5]

echo a[random_int(a.len)]
# Possible output: 3

echo a.random_choice()
# Possible output: 2

a.shuffle()
echo a
# Possible output: @[4, 5, 2, 1, 3]

if random_bool():
    echo "heads"
else:
    echo "tails"
# Possible output: tails

var rng = new_MersenneTwister()
rng.seed(1337)
echo rng.random_int(13..37)
# Reproducible output: 31

rng.seed()
echo rng.random()
# Possible output: 9.9708586245117903e-01
```

[Documentation](https://raw.githubusercontent.com/BlaXpirit/nimrod-random/master/doc/random.html)
