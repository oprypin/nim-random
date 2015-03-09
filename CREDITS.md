This library was made by [Oleh Prypin][BlaXpirit].

It was inspired by [Python][]'s [random][1] library and takes some ideas from it.

Thanks to:

- [Varriount][] for helping wrap `CryptGenRandom`
- [flaviut][] for [chi-square testing][a1], [CircleCI example][a2], various comments and pointers
- Jehan for [power-of-two bit mask][a3], various comments and pointers
- [Niklas B.][] for [fast implementation of log2 (`bitSize`)][a4]
- [OderWat][] for [reservoir sampling][a5]
- [Araq][], [def-][], and the rest of the [Nim][] community for answering numerous questions
- Takuji Nishimura and Makoto Matsumoto for [MT19937][b1]
- Sebastiano Vigna for [Xorshift...][b2]
- Taylor R. Campbell for [`random_real`][b3]


[1]: https://docs.python.org/library/random.html

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
