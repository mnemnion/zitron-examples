# Zitron-Examples

Example parsers using [Zitron][zitron], a Zig-native LALR(1) parser
generator.

These are in various states of completeness, at present, rather
less than more.  The [build.zig](./build.zig) file is also intended
as a resource to be used in integrating Zitron parsers into Zig
projects.


## **edn**

The most-complete parser covers [edn format][edn], a data format
which has the same relationship to Clojure as JSON has to JavaScript.

This should not be treated as 'production quality'.  Syntactically,
the largest deviation from the spec is that strings are parsed directly
using Zig's internal string parser, rather than the Java-inflected string
dialect which Clojure expects.  Characters like `\c`, `\tab` etc. are
closer to the specification, although perhaps not identical: this parser
accepts backslash-escaped 'naked' UTF-8, which the specification does not
address.

Semantically there are further differences, particularly surrounding the
semantics of equality between composite types, sets and maps specifically.
The spec also requires duplicate members of those types to be an error,
while this parser keeps the last.

The purpose is to present a completed Zitron grammar, both to shake
out some of the novelties introduced in the process of adapting Zitron
from its origin as a translation of [Lemon][lem], and to demonstrate
the format in a reasonably complete form.  That much I feel has been
achieved.

It should also serve as a substantial head start on parsing s-expressions
for any project which might find that useful.


## Scope and Future Work

This repo exports no usable importable modules, and this is unlikely to
change. It's a showcase: anticipated uses are: browsing, downloading and
building the various artifacts, perhaps copypasting one of the grammars
(with the license, please) into your own project as a basis for further
work.

More grammars may or may not be added.  If someone should want to
contribute a showcase grammar to the collection, feel free to submit one.

Issues are preferred over PRs for any bugs you may discover here.
It would be surprising if even the complete grammar were rigorously
correct, given that effort has not been expended to make any of it so.
Bugs in Zitron I will endeavor to fix (and of course belong on that
issue board, not this one), bugs in the examples may or may not be, time
and interest permitting.

[zitron]: https://github.com/mnemnion/zitron
[edn]: https://github.com/edn-format/edn
[lem]: https://sqlite.org/lemon.html
