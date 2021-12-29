    P.S. What is the best way to make array-set hybrid? I.e. array, where order of elements matters, but it also supports accelerated "in" operation with minimal memory cost.

Any sorted structure needs to have roughly the primitives for the IN operator to find the insertion point of an item. So usually they will have something.

I never really solved it, but worked around that in 2015 or so by polishing something I've done years ago (2004-5). It is not really a final solution, but it works within some realistic boundaries and has some nice properties. The newer version of it is at http://www.stack.nl/~marcov/lightcontainers.zip

Originally I was using a sorted Tstringlist and its insert performance started to slow down catastrophically (100k-300k elements). After a short excursion (to the Decal components, too much constant time overhead), I quickly whipped an extra level of indirection (array of array instead of linear array). That postponed the insertion problem off till 5-10M.

Because most iterations were for loops, I changed to an iterator to hide the internals.

Later I generalized this with generics, so I could also use non-string types as keys, and some time later again I added for..in iterators. I still use it for some of my larger datastructures.  I mostly either use TDictionary (a hash) or this.

@marcov at https://forum.lazarus.freepascal.org/index.php/topic,57616.msg429043.html#msg429043
