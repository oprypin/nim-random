nim-random
==========

Random number generation library for [Nim][] inspired by [Python's "random" module][1]

[![Build Status](https://circleci.com/gh/BlaXpirit/nim-random.png?style=shield)](https://circleci.com/gh/BlaXpirit/nim-random)

---

Contents
--------

- [Example](#example)
- [Manual](#manual)
  - [Common Operations](#common-operations)
    - [Random Integers](#random-integers)
    - [Random Reals](#random-reals)
    - [Sequence Operations](#sequence-operations)
  - [Type Glossary](#type-glossary)
  - [Random Number Generators](#random-number-generators)
    - [*urandom*](#randomurandom)
      - [`SystemRandom`](#type-systemrandom)
    - [*mersenne*](#randommersenne)
      - [`MersenneTwister`](#type-mersennetwister)
    - [*xorshift*](#randomxorshift)
      - [`Xorshift128Plus`](#type-xorshift128plus)
      - [`Xorshift1024Star`](#type-xorshift1024star)
    - [Custom RNGs](#custom-rngs)
- [Generated Documentation][doc]
- [Credits](#credits)

---

Example
-------

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
# Reproducible output: @[9, 10, 5]

var rng2 = initMersenneTwister(urandom(2500))
echo rng2.random()
# Possible output: 0.6097267717528587
```

---

Manual
------

### Common Operations

The following procedures work for [every](#random-number-generators) random number generator (`import random.*`). The first argument is skipped here; it is always `var RNG`, so you would write, for example, `rng.shuffle(arr)`.

You can also do `import random` and get access to these exact procedures without the first argument. They use a global instance of [Mersenne twister](#randommersenne), which is seeded using an array of bytes provided by [`urandom`](#randomurandom), or, in case of failure, the current time. Due to this silent fallback and the fact that any other code can use this global instance (and there is no thread safety), it is not recommended to do this if you have any concerns for security.


#### Random Integers

```nim
proc randomInt(T: typedesc[SomeInteger]): T
```

Returns a uniformly distributed random integer `T.low <= x <= T.high`

```nim
proc randomInt(max: Positive): Natural
```

Returns a uniformly distributed random integer `0 <= x < max`

```nim
proc randomInt(min, max: int): int
```

Returns a uniformly distributed random integer `min <= x < max`

```nim
proc randomInt(range: Slice[int]): int
```

Returns a uniformly distributed random integer `range.a <= x <= range.b`

```nim
proc randomBool(): bool
```

Returns a random boolean

#### Random Reals

```nim
proc random(): float64
```

Returns a uniformly distributed random number `0 <= x < 1`

```nim
proc random(max: float): float
```

Returns a uniformly distributed random number `0 <= x < max`

```nim
proc random(min, max: float): float
```

Returns a uniformly distributed random number `min <= x < max`

```nim
proc randomPrecise(): float64
```

Returns a uniformly distributed random number `0 <= x <= 1`,
with more resolution (doesn't skip values).

Based on http://mumble.net/~campbell/2014/04/28/uniform-random-float

#### Sequence Operations

```nim
proc randomChoice(arr: RAContainer): auto
```

Selects a random element (all of them have an equal chance)
from a random access container and returns it

```nim
proc shuffle(arr: var RAContainer)
```

Randomly shuffles elements of a random access container.

```nim
iterator randomSample(range: Slice[int]; n: Natural): int
```

Yields `n` random integers `range.a <= x <= range.b` in random order.
Each number has an equal chance to be picked and can be picked only once.

Raises `ValueError` if there are less than `n` items in `range`.

```nim
iterator randomSample(arr: RAContainer; n: Natural): auto
```

Yields `n` items randomly picked from a random access container `arr`,
in random order. Each item has an equal chance to be picked
and can be picked only once. Duplicate items are allowed in `arr`,
and they will not be treated in any special way.

Raises `ValueError` if there are less than `n` items in `arr`.

```nim
proc randomSample[T](iter: iterator(): T; n: Natural): seq[T]
```

Random sample using reservoir sampling algorithm.

Returns a sequence of `n` items randomly picked from an iterator `iter`,
in no particular order. Each item has an equal chance to be picked and can
be picked only once. Repeating items are allowed in `iter`, and they will
not be treated in any special way.

Raises `ValueError` if there are less than `n` items in `iter`.

---

### Type Glossary

##### `RNG`

Random number generator typeclass. See [custom RNGs](#custom-rngs).

##### `typedesc[SomeInteger]`

Pass any integer type as an argument.

##### `Positive`, `Natural`

`int > 0`, `int >= 0`

##### `Slice[int]`

`a..b`

##### `RAContainer`

Random access container typeclass. Should support `len`, `low`, `high`, `[]`. Examples: `array`, `seq`.

---

### Random Number Generators

Pseudo random number generators are objects that have some state associated with them. You can create as many independent RNG objects as you like. If you use the same seed, you will always get the same sequence of numbers.

If you need to generate important things such as passwords, use [*random.urandom*](#randomurandom) or `SystemRandom`, but for typical usage it is much better to only use `urandom` to seed a pseudo-random number generator, as shown at the bottom of the [example](#example).

None of the operations are thread-safe, so if you want to use random number generation in multiple threads, just make a different RNG object in each thread.


#### *random.urandom*

```nim
proc urandom(size: Natural): seq[uint8]
```

Returns a `seq` of random integers `0 <= n < 256` provided by
the operating system's cryptographic source

POSIX: Reads and returns `size` bytes from the file `/dev/urandom`.

Windows: Returns `size` bytes obtained by calling `CryptGenRandom`.
Initialization is done before the first call with
`CryptAcquireContext(..., PROV_RSA_FULL, CRYPT_VERIFYCONTEXT)`.

Raises `OSError` on failure.

##### type SystemRandom

Random number generator based on bytes provided by
the operating system's cryptographic source (see `urandom`)

- Period: none
- State: none (but bytes are obtained in 128-byte chunks)

```nim
proc initSystemRandom(): SystemRandom
```

Initializes and returns a new `SystemRandom`

#### *random.mersenne*

##### type MersenneTwister

Mersenne Twister (MT19937). Based on
http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/MT2002/emt19937ar.html

- Period: 2<sup>19937</sup>
- State: 2496 bytes + int

```nim
proc initMersenneTwister(seed: openArray[uint32]): MersenneTwister
```

Seeds a new `MersenneTwister` with an array of `uint32`

```nim
proc initMersenneTwister(seed: openArray[uint8]): MersenneTwister
```

Seeds a new `MersenneTwister` with an array of bytes

```nim
proc initMersenneTwister(seed: uint32): MersenneTwister
```

Seeds a new `MersenneTwister` with an `uint32`

#### *random.xorshift*

##### type Xorshift128Plus

xorshift128+.
Based on http://xorshift.di.unimi.it/

- Period: 2<sup>128</sup> - 1
- State: 16 bytes

```nim
proc initXorshift128Plus(seed: array[2, uint64]): Xorshift128Plus
```

Seeds a new `Xorshift128Plus` with 2 `uint64`.

Raises `ValueError` if the seed consists of only zeros.

```nim
proc initXorshift128Plus(seed: array[16, uint8]): Xorshift128Plus
```

Seeds a new `Xorshift128Plus` with an array of 16 bytes.

Raises `ValueError` if the seed consists of only zeros.

```nim
proc initXorshift128Plus(seed: uint64): Xorshift128Plus
```

Seeds a new `Xorshift128Plus` with an `uint64`.

Raises `ValueError` if the seed consists of only zeros.

##### type Xorshift1024Star

xorshift1024*.
Based on http://xorshift.di.unimi.it/

- Period: 2<sup>1024</sup> - 1
- State: 128 bytes + int

```nim
proc initXorshift1024Star(seed: array[16, uint64]): Xorshift1024Star
```

Seeds a new `Xorshift1024Star` with 16 `uint64`.

Raises `ValueError` if the seed consists of only zeros.

```nim
proc initXorshift1024Star(seed: array[128, uint8]): Xorshift1024Star
```

Seeds a new `Xorshift1024Star` with an array of 128 bytes.

Raises `ValueError` if the seed consists of only zeros.

```nim
proc initXorshift1024Star(seed: uint64): Xorshift1024Star
```

Seeds a new `Xorshift1024Star` using an `uint64`.

Raises `ValueError` if the seed consists of only zeros.


### Custom RNGs

The typeclass `RNG` requires any of:

- `rng.randomUint8() is uint8`
- `rng.randomUint32() is uint32`
- `rng.randomUint64() is uint64`

So all you need to make another random number generator compatible with this library is to implement one of these procs, for example:

```nim
proc randomUint32*(self: var MersenneTwister): uint32 =
```

This should return a uniformly distributed random number.

You may also override any of the [common operations](#common-operations) for your RNG; `random()` would be the first candidate for this.

Other than this, you should make `init...` procs to create and seed your RNG. It is important to be able to seed with an array of bytes, for convenience of use with [`urandom`](#randomurandom). Look in the source code to see how *random/private/util*`.bytesToWords` and `bytesToWordsN` are used to quickly create byte-array seeding based on some other seeding proc.

Don't forget to import+export *random.common*.

---

## [Generated Documentation][doc]

---

Credits
-------

This library was made by [Oleh Prypin][BlaXpirit].

It was inspired by [Python][]'s [random][1] library and takes some ideas from it.

Thanks to:

- [Varriount][] for helping wrap `CryptGenRandom`
- [flaviut][] for [chi-square testing][a1], [CircleCI example][a2], various comments and pointers
- Jehan for various comments and pointers
- [Niklas B.][] for [fast implementation of log2 (`bitSize`)][a4]
- [OderWat][] for [reservoir sampling][a5]
- [Araq][], [def-][], and the rest of the [Nim][] community for answering numerous questions
- Takuji Nishimura and Makoto Matsumoto for [MT19937][b1]
- Sebastiano Vigna for [Xorshift...][b2]
- Taylor R. Campbell for [`random_real`][b3]



[doc]: http://blaxpirit.github.io/nim-random/

[1]: https://docs.python.org/3/library/random.html

[a1]: https://github.com/flaviut/furry-happiness/blob/master/test/cappedRandom.nim
[a2]: http://flaviut.github.io/2015/02/08/circleci-nim/
[a3]: http://forum.nim-lang.org/t/533#2886
[a4]: http://stackoverflow.com/questions/21888140/de-bruijn-algorithm-binary-digit-count-64bits-c-sharp/21888542#21888542
[a5]: https://github.com/BlaXpirit/nim-random/commit/ba4dc9a836ab74aec5ece12852953d29d0d6ced2

[b1]: http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/MT2002/emt19937ar.html
[b2]: http://xorshift.di.unimi.it/
[b3]: http://mumble.net/~campbell/2014/04/28/random_real.c

[BlaXpirit]: https://github.com/BlaXpirit
[Varriount]: https://github.com/Varriount
[flaviut]: https://github.com/flaviut
[Niklas B.]: http://stackoverflow.com/users/916657/niklas-b
[OderWat]: https://github.com/oderwat
[Araq]: https://github.com/Araq
[def-]: https://github.com/def-

[Nim]: http://nim-lang.org/
[Python]: http://python.org/
